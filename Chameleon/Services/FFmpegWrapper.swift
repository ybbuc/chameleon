//
//  FFmpegWrapper.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import Foundation

class FFmpegWrapper {
    private let ffmpegPath: String
    private var currentProcess: Process?
    
    init() throws {
        // Use system ffmpeg from PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["ffmpeg"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                print("Found ffmpeg at: \(path)")
                self.ffmpegPath = path
                return
            }
        }
        
        // Fallback to common locations
        let commonPaths = [
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
            "/opt/local/bin/ffmpeg"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path) {
                print("Found ffmpeg at fallback location: \(path)")
                self.ffmpegPath = path
                return
            } else if FileManager.default.fileExists(atPath: path) {
                print("File exists but not executable: \(path)")
            }
        }
        
        throw FFmpegError.ffmpegNotInstalled
    }
    
    func convertFile(inputURL: URL, outputURL: URL, format: FFmpegFormat, quality: FFmpegQuality = .medium, audioOptions: AudioOptions? = nil) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        
        var arguments = [
            "-i", inputURL.path,
            "-y" // Overwrite output file
        ]
        
        // Add format-specific arguments
        if let audioOptions = audioOptions, !format.isVideo {
            // Use custom audio options for audio formats
            arguments.append(contentsOf: format.codecArguments())
            arguments.append(contentsOf: audioOptions.ffmpegArguments(for: format))
        } else {
            // Use default format arguments
            arguments.append(contentsOf: format.arguments(quality: quality))
        }
        
        arguments.append(outputURL.path)
        
        process.arguments = arguments
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        
        // Wait for completion with cancellation support
        currentProcess = process
        defer { currentProcess = nil }
        
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw FFmpegError.conversionFailed(errorString)
        }
    }
    
    func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
    }
    
    func getFileInfo(url: URL) async throws -> MediaFileInfo {
        let process = Process()
        
        // Use ffprobe (should be in same location as ffmpeg)
        let ffprobePath = ffmpegPath.replacingOccurrences(of: "ffmpeg", with: "ffprobe")
        process.executableURL = URL(fileURLWithPath: ffprobePath)
        
        process.arguments = [
            "-v", "quiet",
            "-print_format", "json",
            "-show_format",
            "-show_streams",
            url.path
        ]
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw FFmpegError.conversionFailed("ffprobe failed: \(errorString)")
        }
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        
        do {
            let decoder = JSONDecoder()
            let probeResult = try decoder.decode(FFProbeResult.self, from: outputData)
            return MediaFileInfo(from: probeResult)
        } catch {
            throw FFmpegError.conversionFailed("Failed to parse ffprobe output: \(error)")
        }
    }
}

struct FFProbeResult: Codable {
    let format: FFProbeFormat
    let streams: [FFProbeStream]
}

struct FFProbeFormat: Codable {
    let filename: String
    let formatName: String
    let formatLongName: String?
    let duration: String?
    let size: String?
    let bitRate: String?
    
    enum CodingKeys: String, CodingKey {
        case filename
        case formatName = "format_name"
        case formatLongName = "format_long_name"
        case duration
        case size
        case bitRate = "bit_rate"
    }
}

struct FFProbeStream: Codable {
    let index: Int
    let codecName: String?
    let codecType: String
    let width: Int?
    let height: Int?
    let sampleRate: String?
    let channels: Int?
    let channelLayout: String?
    let duration: String?
    
    enum CodingKeys: String, CodingKey {
        case index
        case codecName = "codec_name"
        case codecType = "codec_type"
        case width
        case height
        case sampleRate = "sample_rate"
        case channels
        case channelLayout = "channel_layout"
        case duration
    }
}

struct MediaFileInfo {
    let formatName: String
    let hasVideo: Bool
    let hasAudio: Bool
    let videoCodec: String?
    let audioCodec: String?
    let duration: TimeInterval?
    
    init(from probeResult: FFProbeResult) {
        self.formatName = probeResult.format.formatName
        
        let videoStreams = probeResult.streams.filter { $0.codecType == "video" }
        let audioStreams = probeResult.streams.filter { $0.codecType == "audio" }
        
        self.hasVideo = !videoStreams.isEmpty
        self.hasAudio = !audioStreams.isEmpty
        self.videoCodec = videoStreams.first?.codecName
        self.audioCodec = audioStreams.first?.codecName
        
        if let durationString = probeResult.format.duration,
           let durationValue = Double(durationString) {
            self.duration = durationValue
        } else {
            self.duration = nil
        }
    }
}

enum FFmpegFormat: String, CaseIterable {
    // Video formats
    case mp4 = "mp4"
    case mov = "mov"
    case avi = "avi"
    case mkv = "mkv"
    case webm = "webm"
    case flv = "flv"
    case wmv = "wmv"
    case m4v = "m4v"
    
    // Audio formats
    case mp3 = "mp3"
    case aac = "aac"
    case wav = "wav"
    case flac = "flac"
    case alac = "alac"
    case ogg = "ogg"
    case wma = "wma"
    case aiff = "aiff"
    
    var displayName: String {
        switch self {
        case .mp4: return "MP4 Video"
        case .mov: return "QuickTime Movie"
        case .avi: return "AVI Video"
        case .mkv: return "Matroska Video"
        case .webm: return "WebM Video"
        case .flv: return "Flash Video"
        case .wmv: return "Windows Media Video"
        case .m4v: return "iTunes Video"
        case .mp3: return "MP3 Audio"
        case .aac: return "AAC Audio"
        case .wav: return "WAV Audio"
        case .flac: return "FLAC Audio"
        case .alac: return "ALAC Audio"
        case .ogg: return "Ogg Vorbis"
        case .wma: return "Windows Media Audio"
        case .aiff: return "AIFF Audio"
        }
    }
    
    var description: String? {
        switch self {
        case .mp4: return nil
        case .mov: return nil
        case .avi: return nil
        case .mkv: return nil
        case .webm: return nil
        case .flv: return nil
        case .wmv: return nil
        case .m4v: return nil
        case .aiff: return "Lossless, but the files are quite large. Standard on Apple platforms, but less common than WAV elsewhere."
        case .mp3: return "Lossy, but the files are very compact and can be played in almost any application."
        case .aac: return "Lossy, though less than MP3. The files are very compact, and are generally well supported by most applications."
        case .wav: return "Lossless, but the files are enormous. They can be played by almost any application."
        case .flac: return "Lossless, but the files are quite large. It's popular among audiophiles, but playback is supported in few audio players."
        case .alac: return "Lossless, but the files are quite large. Standard on Apple platforms, but less universal elsewhere."
        case .ogg: return "Lossy, with quality often better than MP3 at similar bitrates. While the files are compact, it's not as universally supported as MP3 or AAC."
        case .wma: return "Lossy, with quality comparable to MP3. It's well-supported on Windows but less common on other platforms."
        }
    }
    
    var fileExtension: String {
        switch self {
        case .aac, .alac:
            return "m4a"
        default:
            return rawValue
        }
    }
    
    var isVideo: Bool {
        switch self {
        case .mp4, .mov, .avi, .mkv, .webm, .flv, .wmv, .m4v:
            return true
        case .mp3, .aac, .wav, .flac, .alac, .ogg, .wma, .aiff:
            return false
        }
    }
    
    func arguments(quality: FFmpegQuality) -> [String] {
        var args: [String] = []
        
        switch self {
        case .mp4:
            args.append(contentsOf: ["-c:v", "libx264", "-c:a", "aac"])
            args.append(contentsOf: quality.videoArguments)
        case .mov:
            args.append(contentsOf: ["-c:v", "libx264", "-c:a", "aac"])
            args.append(contentsOf: quality.videoArguments)
        case .avi:
            args.append(contentsOf: ["-c:v", "libx264", "-c:a", "mp3"])
            args.append(contentsOf: quality.videoArguments)
        case .mkv:
            args.append(contentsOf: ["-c:v", "libx264", "-c:a", "aac"])
            args.append(contentsOf: quality.videoArguments)
        case .webm:
            args.append(contentsOf: ["-c:v", "libvpx-vp9", "-c:a", "libvorbis"])
            args.append(contentsOf: quality.videoArguments)
        case .flv:
            args.append(contentsOf: ["-c:v", "libx264", "-c:a", "aac"])
            args.append(contentsOf: quality.videoArguments)
        case .wmv:
            args.append(contentsOf: ["-c:v", "wmv2", "-c:a", "wmav2"])
            args.append(contentsOf: quality.videoArguments)
        case .m4v:
            args.append(contentsOf: ["-c:v", "libx264", "-c:a", "aac"])
            args.append(contentsOf: quality.videoArguments)
        case .mp3:
            args.append(contentsOf: ["-c:a", "libmp3lame"])
            args.append(contentsOf: quality.audioArguments)
        case .aac:
            args.append(contentsOf: ["-c:a", "aac"])
            args.append(contentsOf: quality.audioArguments)
        case .wav:
            // WAV codec and sample format will be handled by AudioOptions
            args.append(contentsOf: ["-c:a", "pcm_s16le"])
        case .flac:
            args.append(contentsOf: ["-c:a", "flac"])
        case .alac:
            args.append(contentsOf: ["-c:a", "alac"])
        case .ogg:
            args.append(contentsOf: ["-c:a", "libvorbis"])
            args.append(contentsOf: quality.audioArguments)
        case .wma:
            args.append(contentsOf: ["-c:a", "wmav2"])
            args.append(contentsOf: quality.audioArguments)
        case .aiff:
            // AIFF codec and sample format will be handled by AudioOptions
            args.append(contentsOf: ["-f", "aiff"])
        }
        
        return args
    }
    
    func codecArguments() -> [String] {
        switch self {
        case .mp4, .mov:
            return ["-c:v", "libx264", "-c:a", "aac"]
        case .avi:
            return ["-c:v", "libx264", "-c:a", "libmp3lame"]
        case .mkv:
            return ["-c:v", "libx264", "-c:a", "aac"]
        case .webm:
            return ["-c:v", "libvpx-vp9", "-c:a", "libvorbis"]
        case .flv:
            return ["-c:v", "libx264", "-c:a", "aac"]
        case .wmv:
            return ["-c:v", "wmv2", "-c:a", "wmav2"]
        case .m4v:
            return ["-c:v", "libx264", "-c:a", "aac"]
        case .mp3:
            return ["-c:a", "libmp3lame"]
        case .aac:
            return ["-c:a", "aac"]
        case .wav:
            return ["-c:a", "pcm_s16le"]
        case .flac:
            return ["-c:a", "flac"]
        case .alac:
            return ["-c:a", "alac"]
        case .ogg:
            return ["-c:a", "libvorbis"]
        case .wma:
            return ["-c:a", "wmav2"]
        case .aiff:
            return ["-f", "aiff"]
        }
    }
    
    // Accurate format detection using ffprobe analysis
    static func detectFormatAccurate(from url: URL) async -> FFmpegFormat? {
        do {
            let wrapper = try FFmpegWrapper()
            let fileInfo = try await wrapper.getFileInfo(url: url)
            return FFmpegFormat.fromProbeInfo(fileInfo)
        } catch {
            // Fall back to extension-based detection if ffprobe fails
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
    
    // Map ffprobe format info to FFmpegFormat
    static func fromProbeInfo(_ info: MediaFileInfo) -> FFmpegFormat? {
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
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryhigh = "veryhigh"
    
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
            return "FFmpeg is not installed. Please install it via Homebrew: brew install ffmpeg"
        case .conversionFailed(let message):
            return "FFmpeg conversion failed: \(message)"
        }
    }
}
