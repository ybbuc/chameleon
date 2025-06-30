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
    
    func convertFile(inputURL: URL, outputURL: URL, format: FFmpegFormat, quality: FFmpegQuality = .medium, audioOptions: AudioOptions? = nil, videoOptions: VideoOptions? = nil) async throws {
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
        } else if let videoOptions = videoOptions, format.isVideo {
            // Use custom video options for video formats
            arguments.append(contentsOf: format.codecArguments())
            arguments.append(contentsOf: videoOptions.ffmpegArguments(for: format))
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
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw FFmpegError.conversionFailed(errorString)
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
