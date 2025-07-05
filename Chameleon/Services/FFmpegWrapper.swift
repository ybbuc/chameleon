//
//  FFmpegWrapper.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import Foundation
import Darwin

class FFmpegWrapper {
    private let ffmpegPath: String
    private var activeProcesses = Set<Process>()
    private let processQueue = DispatchQueue(label: "com.chameleon.ffmpeg", attributes: .concurrent)
    private let mediaInfoWrapper: MediaInfoWrapper?

    init() throws {
        // Use only bundled ffmpeg binary
        guard let bundlePath = Bundle.main.path(forResource: "ffmpeg", ofType: nil) else {
            throw FFmpegError.ffmpegNotInstalled
        }
        
        guard FileManager.default.fileExists(atPath: bundlePath) && FileManager.default.isExecutableFile(atPath: bundlePath) else {
            throw FFmpegError.ffmpegNotInstalled
        }
        
        print("Using bundled FFmpeg at: \(bundlePath)")
        self.ffmpegPath = bundlePath
        
        // Initialize MediaInfoWrapper for media analysis
        do {
            self.mediaInfoWrapper = try MediaInfoWrapper()
            print("✅ MediaInfoLib initialized successfully")
        } catch {
            print("❌ Failed to initialize MediaInfoLib: \(error)")
            print("   Error details: \(error.localizedDescription)")
            self.mediaInfoWrapper = nil
        }
    }

    func convertFile(inputURL: URL, outputURL: URL, format: FFmpegFormat, quality: FFmpegQuality = .medium, audioOptions: AudioOptions? = nil, videoOptions: VideoOptions? = nil) async throws {
        // Special handling for GIF with palette optimization
        if format == .gif, let videoOptions = videoOptions, videoOptions.gifOptions.usePalette {
            try await performGIFConversionWithPalette(inputURL: inputURL, outputURL: outputURL, videoOptions: videoOptions)
            return
        }

        // Check if we need two-pass encoding
        if let videoOptions = videoOptions,
           format.isVideo,
           videoOptions.qualityMode == .bitrate,
           videoOptions.useTwoPassEncoding {
            // Perform two-pass encoding
            try await performTwoPassEncoding(inputURL: inputURL, outputURL: outputURL, format: format, videoOptions: videoOptions)
            return
        }

        // Single-pass encoding
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)

        var arguments = [
            "-i", inputURL.path,
            "-y" // Overwrite output file
        ]

        // Check if input is a subtitle file
        let inputFormat = FFmpegFormat.detectFormat(from: inputURL)
        let isSubtitleInput = inputFormat?.isSubtitle ?? false
        
        // Special handling for subtitle conversion
        if format.isSubtitle {
            if isSubtitleInput {
                // Subtitle-to-subtitle conversion
                arguments.append(contentsOf: format.codecArguments())
            } else {
                // Extract subtitles from video
                arguments.append(contentsOf: ["-map", "0:s:0"]) // Map first subtitle stream
                arguments.append(contentsOf: format.codecArguments())
            }
        }
        // Special handling for OGG format with video input
        else if format == .ogg && videoOptions != nil {
            // OGG with video should use VP8 codec (since Theora encoder is not available)
            // OGG with video should use VP8 codec (since Theora encoder is not available)
            arguments.append(contentsOf: ["-c:v", "libvpx", "-c:a", "libvorbis"])
            if let videoOptions = videoOptions {
                arguments.append(contentsOf: videoOptions.ffmpegArguments(for: format))
            }
        }
        // Add format-specific arguments
        else if let audioOptions = audioOptions, !format.isVideo {
            // Use custom audio options for audio formats
            arguments.append(contentsOf: format.codecArguments())
            arguments.append(contentsOf: audioOptions.ffmpegArguments(for: format))
        } else if let videoOptions = videoOptions, format.isVideo {
            // Use custom video options for video formats
            if let config = FormatRegistry.shared.config(for: format) {
                arguments.append(contentsOf: config.codecArguments(for: videoOptions.encoder))
            } else {
                arguments.append(contentsOf: format.codecArguments())
            }
            arguments.append(contentsOf: videoOptions.ffmpegArguments(for: format))
        } else {
            // Use default format arguments
            arguments.append(contentsOf: format.arguments(quality: quality))
        }

        arguments.append(outputURL.path)

        // Set the arguments
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        // Also capture stdout to see all messages
        let outputPipe = Pipe()
        process.standardOutput = outputPipe

        try process.run()
        
        // Use centralized process runner
        try await runFFmpegProcess(process)

        // Always read the output, even on success
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        
        if process.terminationStatus != 0 {
            let errorString = String(data: errorData, encoding: .utf8) ?? ""
            let outputString = String(data: outputData, encoding: .utf8) ?? ""
            let fullOutput = "STDERR:\n\(errorString)\n\nSTDOUT:\n\(outputString)"
            
            // Check if the output file was actually created despite non-zero exit
            if FileManager.default.fileExists(atPath: outputURL.path) {
                // File exists, so conversion likely succeeded despite exit code
                // Exit code 11 (SIGSEGV) can occur during cleanup after successful conversion
                if process.terminationStatus == 11 && format == .ogg {
                    // Known issue with VP8/Vorbis in OGG container - conversion succeeds but FFmpeg crashes during cleanup
                    print("Note: FFmpeg experienced a post-conversion cleanup issue with OGG format, but the file was created successfully")
                } else {
                    print("Warning: FFmpeg returned exit code \(process.terminationStatus) but output file exists")
                    // Only print full output for non-OGG formats or non-11 exit codes
                    if !(process.terminationStatus == 11 && format == .ogg) {
                        print("FFmpeg output:\n\(fullOutput)")
                    }
                }
                return
            }
            
            throw FFmpegError.conversionFailed(fullOutput)
        }
    }

    private func registerProcess(_ process: Process) {
        _ = processQueue.sync(flags: .barrier) {
            self.activeProcesses.insert(process)
        }
    }
    
    private func unregisterProcess(_ process: Process) {
        _ = processQueue.sync(flags: .barrier) {
            self.activeProcesses.remove(process)
        }
    }
    
    func cancel() {
        let processesToCancel = processQueue.sync(flags: .barrier) { () -> [Process] in
            let processes = Array(activeProcesses)
            return processes
        }
        
        // Kill processes outside the queue to avoid deadlock
        for process in processesToCancel {
            let processID = process.processIdentifier
            if processID > 0 {
                // Kill the process group to get any child processes
                killpg(processID, SIGKILL)
                // Also kill the individual process to be sure
                kill(processID, SIGKILL)
            }
        }
        
        // Clear the set after cancelling all
        processQueue.sync(flags: .barrier) {
            activeProcesses.removeAll()
        }
    }
    
    // Centralized FFmpeg process execution with proper cancellation handling
    private func runFFmpegProcess(_ process: Process) async throws {
        let processID = process.processIdentifier
        
        // Register with both our tracking and ProcessManager
        ProcessManager.shared.register(process)
        registerProcess(process)
        
        // Monitor for cancellation while process runs
        var cancelled = false
        while process.isRunning {
            if Task.isCancelled {
                cancelled = true
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        
        // If cancelled, kill the process
        if cancelled && processID > 0 {
            kill(processID, SIGKILL)
            // Also kill the process group to get any child processes
            killpg(processID, SIGKILL)
            // Give it a moment to die
            try? await Task.sleep(for: .milliseconds(200))
        }
        
        // Wait for process to finish
        process.waitUntilExit()
        
        // Now unregister
        unregisterProcess(process)
        ProcessManager.shared.unregister(process)
        
        // Throw if we were cancelled
        if cancelled {
            throw CancellationError()
        }
    }

    func getMediaInfo(url: URL) async throws -> MediaFileInfo {
        return try await getFileInfo(url: url)
    }

    private func performTwoPassEncoding(inputURL: URL, outputURL: URL, format: FFmpegFormat, videoOptions: VideoOptions) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let logFileBase = tempDir.appendingPathComponent("ffmpeg2pass-\(UUID().uuidString)")

        // First pass
        try await runPass(
            1,
            inputURL: inputURL,
            outputURL: URL(fileURLWithPath: "/dev/null"),
            format: format,
            videoOptions: videoOptions,
            logFile: logFileBase.path
        )

        // Second pass
        try await runPass(
            2,
            inputURL: inputURL,
            outputURL: outputURL,
            format: format,
            videoOptions: videoOptions,
            logFile: logFileBase.path
        )

        // Clean up log files
        try? FileManager.default.removeItem(at: logFileBase.appendingPathExtension("0.log"))
        try? FileManager.default.removeItem(at: logFileBase.appendingPathExtension("0.log.mbtree"))
    }

    private func runPass(_ pass: Int, inputURL: URL, outputURL: URL, format: FFmpegFormat, videoOptions: VideoOptions, logFile: String) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)

        var arguments = [
            "-i", inputURL.path,
            "-y" // Overwrite output file
        ]

        // Add codec arguments
        if let config = FormatRegistry.shared.config(for: format) {
            arguments.append(contentsOf: config.codecArguments(for: videoOptions.encoder))
        } else {
            arguments.append(contentsOf: format.codecArguments())
        }

        // Add pass-specific arguments
        arguments.append(contentsOf: videoOptions.ffmpegArgumentsForPass(pass, for: format, logFile: logFile))

        if pass == 1 {
            // First pass outputs to null
            arguments.append("/dev/null")
        } else {
            // Second pass outputs to final file
            arguments.append(outputURL.path)
        }

        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()

        // Use centralized process runner
        try await runFFmpegProcess(process)

        // Check if process exited successfully
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw FFmpegError.conversionFailed("FFmpeg pass \(pass) failed: \(errorString)")
        }
    }

    private func performGIFConversionWithPalette(inputURL: URL, outputURL: URL, videoOptions: VideoOptions) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let paletteFile = tempDir.appendingPathComponent("palette_\(UUID().uuidString).png")

        // First pass: Generate palette
        try await generateGIFPalette(inputURL: inputURL, outputURL: paletteFile, videoOptions: videoOptions)

        // Second pass: Use palette to create GIF
        try await createGIFWithPalette(inputURL: inputURL, paletteURL: paletteFile, outputURL: outputURL, videoOptions: videoOptions)

        // Clean up palette file
        try? FileManager.default.removeItem(at: paletteFile)
    }

    private func generateGIFPalette(inputURL: URL, outputURL: URL, videoOptions: VideoOptions) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)

        // Build filter for palette generation
        var filters: [String] = []
        filters.append("fps=\(videoOptions.gifOptions.fps)")

        // Scale filter
        filters.append("scale=\(videoOptions.gifOptions.width):-1:flags=lanczos")

        filters.append("palettegen")

        process.arguments = [
            "-i", inputURL.path,
            "-vf", filters.joined(separator: ","),
            "-y",
            outputURL.path
        ]

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()

        // Use centralized process runner
        try await runFFmpegProcess(process)

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw FFmpegError.conversionFailed("Failed to generate GIF palette: \(errorString)")
        }
    }

    private func createGIFWithPalette(inputURL: URL, paletteURL: URL, outputURL: URL, videoOptions: VideoOptions) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)

        // Build complex filter for GIF creation with palette
        let fps = videoOptions.gifOptions.fps
        let width = videoOptions.gifOptions.width
        let filterComplex = "fps=\(fps),scale=\(width):-1:flags=lanczos[x];[x][1:v]paletteuse"

        let arguments = [
            "-i", inputURL.path,
            "-i", paletteURL.path,
            "-filter_complex", filterComplex,
            "-loop", "\(videoOptions.gifOptions.loop)",
            "-y",
            outputURL.path
        ]

        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()

        // Use centralized process runner
        try await runFFmpegProcess(process)

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw FFmpegError.conversionFailed("Failed to create GIF: \(errorString)")
        }
    }

    func extractSubtitles(
        inputURL: URL,
        outputDirectory: URL,
        format: FFmpegFormat,
        subtitleInfo: [SubtitleStreamInfo]
    ) async throws -> [URL] {
        var outputURLs: [URL] = []
        
        // Extract all subtitles
        let indicesToExtract = subtitleInfo.map { $0.streamIndex }
        
        // Helper function to sanitize filename
        func sanitizeFilename(_ name: String) -> String {
            let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
            return name.components(separatedBy: invalidChars).joined(separator: "_")
                .trimmingCharacters(in: .whitespaces)
                .prefix(50)  // Limit length
                .trimmingCharacters(in: .whitespaces)
        }
        
        // Generate filenames for each subtitle
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        var usedFilenames = Set<String>()
        
        for index in indicesToExtract {
            guard let subtitle = subtitleInfo.first(where: { $0.streamIndex == index }) else {
                continue
            }
            
            // Build filename components
            var components: [String] = [baseName]
            
            if let language = subtitle.language, !language.isEmpty {
                components.append(sanitizeFilename(language))
            }
            
            if let title = subtitle.title, !title.isEmpty {
                components.append(sanitizeFilename(title))
            }
            
            // If no metadata, use track number
            if components.count == 1 {
                components.append("Track\(index + 1)")
            }
            
            // Join components and add extension
            var filename = components.joined(separator: ".")
            filename += ".\(format.fileExtension)"
            
            // Handle duplicates
            var finalFilename = filename
            var counter = 2
            while usedFilenames.contains(finalFilename) {
                let nameWithoutExt = filename.dropLast(format.fileExtension.count + 1)
                finalFilename = "\(nameWithoutExt).\(counter).\(format.fileExtension)"
                counter += 1
            }
            usedFilenames.insert(finalFilename)
            
            // Extract this subtitle
            let outputURL = outputDirectory.appendingPathComponent(finalFilename)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ffmpegPath)
            process.arguments = [
                "-i", inputURL.path,
                "-map", "0:s:\(index)",
                "-c:s", getSubtitleCodec(for: format),
                "-y",
                outputURL.path
            ]
            
            let errorPipe = Pipe()
            process.standardError = errorPipe
            
            try process.run()
            
            // Use centralized process runner
            try await runFFmpegProcess(process)
            
            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("Failed to extract subtitle \(index): \(errorString)")
                continue  // Skip this subtitle but continue with others
            }
            
            outputURLs.append(outputURL)
        }
        
        if outputURLs.isEmpty {
            throw FFmpegError.conversionFailed("No subtitles were successfully extracted")
        }
        
        return outputURLs
    }
    
    func getFileInfo(url: URL) async throws -> MediaFileInfo {
        // Use MediaInfoLib for media analysis
        guard let mediaInfoWrapper = mediaInfoWrapper else {
            throw FFmpegError.conversionFailed("MediaInfoLib not available for media analysis")
        }
        
        return try mediaInfoWrapper.getFileInfo(url: url)
    }
    
    private func getSubtitleCodec(for format: FFmpegFormat) -> String {
        switch format {
        case .srt:
            return "srt"
        case .webvtt:
            return "webvtt"
        case .ass:
            return "ass"
        case .ssa:
            return "ssa"
        case .ttml:
            return "ttml"
        default:
            return "srt" // fallback
        }
    }
}

struct MediaFileInfo {
    let formatName: String
    let hasVideo: Bool
    let hasAudio: Bool
    let hasSubtitles: Bool
    let videoCodec: String?
    let audioCodec: String?
    let duration: TimeInterval?
    let audioBitDepth: Int?
    let audioSampleRate: Int?
    let audioChannels: Int?
    let audioBitRate: Int?
    
    init(formatName: String, hasVideo: Bool, hasAudio: Bool, hasSubtitles: Bool = false,
         videoCodec: String? = nil, audioCodec: String? = nil, duration: TimeInterval? = nil, 
         audioBitDepth: Int? = nil, audioSampleRate: Int? = nil, audioChannels: Int? = nil, 
         audioBitRate: Int? = nil) {
        self.formatName = formatName
        self.hasVideo = hasVideo
        self.hasAudio = hasAudio
        self.hasSubtitles = hasSubtitles
        self.videoCodec = videoCodec
        self.audioCodec = audioCodec
        self.duration = duration
        self.audioBitDepth = audioBitDepth
        self.audioSampleRate = audioSampleRate
        self.audioChannels = audioChannels
        self.audioBitRate = audioBitRate
    }
}

enum FFmpegFormat: String, CaseIterable {
    // Video formats
    case mp4
    case mov
    case avi
    case mkv
    case webm
    case flv
    case wmv
    case m4v
    case gif

    // Audio formats
    case mp3
    case aac
    case wav
    case flac
    case alac
    case ogg
    case wma
    case aiff
    
    // Subtitle formats
    case srt
    case webvtt
    case ass
    case ssa
    case ttml
    // Note: sub (microdvd), sami, and sbv (subviewer) are decode-only in FFmpeg

    var displayName: String {
        switch self {
        case .webvtt:
            return "WebVTT"
        case .srt:
            return "SRT"
        case .ass:
            return "ASS"
        case .ssa:
            return "SSA"
        case .ttml:
            return "TTML"
        default:
            return rawValue.uppercased()
        }
    }

    var description: String? {
        return FormatRegistry.shared.config(for: self)?.description
    }

    var fileExtension: String {
        return FormatRegistry.shared.config(for: self)?.fileExtension ?? rawValue
    }

    var isVideo: Bool {
        return FormatRegistry.shared.config(for: self)?.isVideo ?? false
    }

    func arguments(quality: FFmpegQuality) -> [String] {
        guard let config = FormatRegistry.shared.config(for: self) else {
            return []
        }

        var args = config.codecArguments()
        args.append(contentsOf: config.qualityArguments(quality: quality))
        return args
    }

    func codecArguments() -> [String] {
        return FormatRegistry.shared.config(for: self)?.codecArguments() ?? []
    }

    var primaryVideoCodec: String? {
        guard let config = FormatRegistry.shared.config(for: self),
              config.isVideo else { return nil }

        let codecArgs = config.codecArguments()
        // Find the video codec argument (follows -c:v)
        if let index = codecArgs.firstIndex(of: "-c:v"),
           index + 1 < codecArgs.count {
            return codecArgs[index + 1]
        }
        return nil
    }

    func primaryVideoCodec(for encoder: VideoEncoder?) -> String? {
        guard let config = FormatRegistry.shared.config(for: self),
              config.isVideo else { return nil }

        let codecArgs = config.codecArguments(for: encoder)
        // Find the video codec argument (follows -c:v)
        if let index = codecArgs.firstIndex(of: "-c:v"),
           index + 1 < codecArgs.count {
            return codecArgs[index + 1]
        }
        return nil
    }

    var supportsCRF: Bool {
        guard let codec = primaryVideoCodec else { return false }
        if case .supported = VideoCodecCRFSupport.forCodec(codec) {
            return true
        }
        return false
    }

    // Accurate format detection using MediaInfoLib analysis
    static func detectFormatAccurate(from url: URL) async -> FFmpegFormat? {
        do {
            let wrapper = try FFmpegWrapper()
            let fileInfo = try await wrapper.getFileInfo(url: url)
            return FFmpegFormat.fromMediaInfo(fileInfo)
        } catch {
            // Fall back to extension-based detection if MediaInfo fails
            return detectFormat(from: url)
        }
    }

    // Fast format detection from file extension (for compatibility)
    static func detectFormat(from url: URL) -> FFmpegFormat? {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "mp4":
            return .mp4
        case "mov":
            return .mov
        case "avi":
            return .avi
        case "mkv":
            return .mkv
        case "webm":
            return .webm
        case "flv":
            return .flv
        case "wmv":
            return .wmv
        case "m4v":
            return .m4v
        case "gif":
            return .gif
        case "mp3":
            return .mp3
        case "aac":
            return .aac
        case "wav":
            return .wav
        case "flac":
            return .flac
        case "ogg":
            return .ogg
        case "m4a":
            return .aac  // Default M4A files to AAC
        case "wma":
            return .wma
        case "aiff", "aif":
            return .aiff
        case "srt":
            return .srt
        case "vtt", "webvtt":
            return .webvtt
        case "ass":
            return .ass
        case "ssa":
            return .ssa
        case "ttml", "dfxp":
            return .ttml
        default:
            return nil
        }
    }
    
    var isSubtitle: Bool {
        switch self {
        case .srt, .webvtt, .ass, .ssa, .ttml:
            return true
        default:
            return false
        }
    }

    // Map MediaInfo format info to FFmpegFormat
    static func fromMediaInfo(_ info: MediaFileInfo) -> FFmpegFormat? {
        let formatNames = info.formatName.lowercased().split(separator: ",")

        // Handle container formats that could contain different codecs
        if formatNames.contains("mov") || formatNames.contains("mp4") || formatNames.contains("m4a") {
            if info.hasVideo {
                if formatNames.contains("mov") {
                    return .mov
                } else {
                    return .mp4
                }
            } else if info.hasAudio {
                // Audio-only M4A/MP4 container - determine by codec
                if let audioCodec = info.audioCodec {
                    switch audioCodec.lowercased() {
                    case "alac":
                        return .alac
                    case "aac":
                        return .aac
                    default:
                        return .aac  // Default to AAC for M4A
                    }
                }
                return .aac
            }
        }

        // Direct format mapping
        for formatName in formatNames {
            switch formatName.trimmingCharacters(in: .whitespaces) {
            case "avi":
                return .avi
            case "matroska", "mkv":
                return .mkv
            case "webm":
                return .webm
            case "flv":
                return .flv
            case "asf":  // Windows Media formats (ASF can contain both video and audio)
                return .wmv
            case "mp3":
                return .mp3
            case "wav":
                return .wav
            case "flac":
                return .flac
            case "ogg":
                return .ogg
            case "aiff":
                return .aiff
            default:
                continue
            }
        }

        return nil
    }
}

enum FFmpegQuality: String, CaseIterable {
    case low
    case medium
    case high
    case veryhigh

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .veryhigh: return "Very High"
        }
    }

    var videoArguments: [String] {
        switch self {
        case .low:
            return ["-crf", "28", "-preset", "fast"]
        case .medium:
            return ["-crf", "23", "-preset", "medium"]
        case .high:
            return ["-crf", "18", "-preset", "slow"]
        case .veryhigh:
            return ["-crf", "15", "-preset", "veryslow"]
        }
    }

    var audioArguments: [String] {
        switch self {
        case .low:
            return ["-b:a", "128k"]
        case .medium:
            return ["-b:a", "192k"]
        case .high:
            return ["-b:a", "256k"]
        case .veryhigh:
            return ["-b:a", "320k"]
        }
    }
}

enum FFmpegError: LocalizedError {
    case ffmpegNotInstalled
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .ffmpegNotInstalled:
            return "Bundled FFmpeg binary not found or not executable."
        case .conversionFailed(let message):
            return "FFmpeg conversion failed: \(message)"
        }
    }
}
