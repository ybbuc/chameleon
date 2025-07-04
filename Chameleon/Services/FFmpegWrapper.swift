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
    private var currentProcess: Process?
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

        // Special handling for OGG format with video input
        if format == .ogg && videoOptions != nil {
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

        // Register with ProcessManager
        ProcessManager.shared.register(process)

        // Wait for completion with cancellation support
        currentProcess = process
        defer {
            currentProcess = nil
            ProcessManager.shared.unregister(process)
        }

        while process.isRunning {
            if Task.isCancelled {
                // Send SIGINT to FFmpeg for graceful shutdown
                let processID = process.processIdentifier
                if processID > 0 {
                    kill(processID, SIGINT)
                }

                // Give FFmpeg a moment to clean up
                for _ in 0..<10 { // Wait up to 1 second
                    if !process.isRunning {
                        break
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }

                // Force terminate if still running
                if process.isRunning {
                    process.terminate()
                }

                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }

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

    func cancel() {
        if let process = currentProcess {
            // FFmpeg handles SIGINT gracefully and will clean up properly
            let processID = process.processIdentifier
            if processID > 0 {
                // Send SIGINT (Ctrl+C) which FFmpeg handles gracefully
                kill(processID, SIGINT)
            }
            currentProcess = nil
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

        // Register with ProcessManager
        ProcessManager.shared.register(process)

        // Wait for completion with cancellation support
        currentProcess = process
        defer {
            currentProcess = nil
            ProcessManager.shared.unregister(process)
        }

        while process.isRunning {
            if Task.isCancelled {
                // Send SIGINT to FFmpeg for graceful shutdown
                let processID = process.processIdentifier
                if processID > 0 {
                    kill(processID, SIGINT)
                }

                // Give FFmpeg a moment to clean up
                for _ in 0..<10 { // Wait up to 1 second
                    if !process.isRunning {
                        break
                    }
                    try await Task.sleep(nanoseconds: 100_000_000) // 100ms
                }

                // Force terminate if still running
                if process.isRunning {
                    process.terminate()
                    process.waitUntilExit()
                }

                throw CancellationError()
            }

            try await Task.sleep(nanoseconds: 100_000_000) // Check every 100ms
        }

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

        // Register with ProcessManager
        ProcessManager.shared.register(process)

        currentProcess = process
        defer {
            currentProcess = nil
            ProcessManager.shared.unregister(process)
        }

        while process.isRunning {
            if Task.isCancelled {
                kill(process.processIdentifier, SIGINT)
                throw CancellationError()
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

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

        // Register with ProcessManager
        ProcessManager.shared.register(process)

        currentProcess = process
        defer {
            currentProcess = nil
            ProcessManager.shared.unregister(process)
        }

        while process.isRunning {
            if Task.isCancelled {
                kill(process.processIdentifier, SIGINT)
                throw CancellationError()
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw FFmpegError.conversionFailed("Failed to create GIF: \(errorString)")
        }
    }

    func getFileInfo(url: URL) async throws -> MediaFileInfo {
        // Use MediaInfoLib for media analysis
        guard let mediaInfoWrapper = mediaInfoWrapper else {
            throw FFmpegError.conversionFailed("MediaInfoLib not available for media analysis")
        }
        
        return try mediaInfoWrapper.getFileInfo(url: url)
    }
}

struct MediaFileInfo {
    let formatName: String
    let hasVideo: Bool
    let hasAudio: Bool
    let videoCodec: String?
    let audioCodec: String?
    let duration: TimeInterval?
    let audioBitDepth: Int?
    let audioSampleRate: Int?
    let audioChannels: Int?
    let audioBitRate: Int?
    
    init(formatName: String, hasVideo: Bool, hasAudio: Bool, videoCodec: String? = nil, 
         audioCodec: String? = nil, duration: TimeInterval? = nil, audioBitDepth: Int? = nil,
         audioSampleRate: Int? = nil, audioChannels: Int? = nil, audioBitRate: Int? = nil) {
        self.formatName = formatName
        self.hasVideo = hasVideo
        self.hasAudio = hasAudio
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

    var displayName: String {
        return rawValue.uppercased()
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
        default:
            return nil
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
