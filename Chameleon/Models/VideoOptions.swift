//
//  VideoOptions.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import Foundation

enum VideoEncoder: String, CaseIterable {
    case x264 = "libx264"
    case x265 = "libx265"

    var displayName: String {
        switch self {
        case .x264:
            return "x264"
        case .x265:
            return "x265"
        }
    }

    var encoderName: String {
        return rawValue
    }
}

enum VideoAspectRatio: String, CaseIterable {
    case automatic = "automatic"
    case fourThree = "4:3"
    case sixteenNine = "16:9"
    case square = "1:1"

    static let standardRatios: [VideoAspectRatio] = [.fourThree, .sixteenNine, .square]

    var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .fourThree:
            return "4:3"
        case .sixteenNine:
            return "16:9"
        case .square:
            return "1:1"
        }
    }

    var width: Int {
        switch self {
        case .automatic:
            return 0 // Not used
        case .fourThree:
            return 4
        case .sixteenNine:
            return 16
        case .square:
            return 1
        }
    }

    var height: Int {
        switch self {
        case .automatic:
            return 0 // Not used
        case .fourThree:
            return 3
        case .sixteenNine:
            return 9
        case .square:
            return 1
        }
    }
}

enum VideoQualityMode: String, CaseIterable {
    case constantRateFactor = "CRF"
    case bitrate = "Bitrate"

    var displayName: String {
        switch self {
        case .constantRateFactor:
            return "Constant"
        case .bitrate:
            return "Target Bitrate"
        }
    }
}

enum VideoBitrate: String, CaseIterable {
    case low = "1M"
    case medium = "2.5M"
    case high = "5M"
    case veryHigh = "10M"
    case ultra = "20M"

    var displayName: String {
        switch self {
        case .low:
            return "1 Mbps"
        case .medium:
            return "2.5 Mbps"
        case .high:
            return "5 Mbps"
        case .veryHigh:
            return "10 Mbps"
        case .ultra:
            return "20 Mbps"
        }
    }

    var ffmpegValue: String {
        return rawValue
    }

    // Recommended bitrate based on resolution
    static func recommended(for resolution: VideoResolution) -> VideoBitrate {
        switch resolution {
        case .automatic:
            return .high  // Default for automatic
        case .res480p, .res576p:
            return .low
        case .res720p:
            return .medium
        case .res1080p:
            return .high
        case .res1440p:
            return .veryHigh
        case .res2160p, .res4320p:
            return .ultra
        }
    }

    // Recommended bitrate value as string
    static func recommendedValue(for resolution: VideoResolution) -> String {
        switch resolution {
        case .automatic:
            return "5"  // Default for automatic
        case .res480p, .res576p:
            return "1"
        case .res720p:
            return "2.5"
        case .res1080p:
            return "5"
        case .res1440p:
            return "10"
        case .res2160p, .res4320p:
            return "20"
        }
    }
}

enum VideoPreset: String, CaseIterable {
    case ultrafast
    case superfast
    case veryfast
    case faster
    case fast
    case medium
    case slow
    case slower
    case veryslow

    var displayName: String {
        switch self {
        case .ultrafast:
            return "Ultrafast"
        case .superfast:
            return "Superfast"
        case .veryfast:
            return "Very Fast"
        case .faster:
            return "Faster"
        case .fast:
            return "Fast"
        case .medium:
            return "Medium"
        case .slow:
            return "Slow"
        case .slower:
            return "Slower"
        case .veryslow:
            return "Very Slow"
        }
    }
}

enum VideoResolution: String, CaseIterable {
    case automatic = "automatic"
    case res480p = "480p"
    case res576p = "576p"
    case res720p = "720p"
    case res1080p = "1080p"
    case res1440p = "1440p"
    case res2160p = "2160p"
    case res4320p = "4320p"

    var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        default:
            return rawValue
        }
    }

    var height: Int {
        switch self {
        case .automatic: return 0    // Not used
        case .res480p: return 480
        case .res576p: return 576
        case .res720p: return 720
        case .res1080p: return 1_080
        case .res1440p: return 1_440
        case .res2160p: return 2_160
        case .res4320p: return 4_320
        }
    }

    var width: Int {
        switch self {
        case .automatic: return 0    // Not used
        case .res480p: return 854    // 16:9
        case .res576p: return 1_024   // 16:9
        case .res720p: return 1_280   // 16:9
        case .res1080p: return 1_920  // 16:9
        case .res1440p: return 2_560  // 16:9
        case .res2160p: return 3_840  // 16:9 (4K)
        case .res4320p: return 7_680  // 16:9 (8K)
        }
    }

    static let standardResolutions: [VideoResolution] = [
        .res480p, .res576p, .res720p, .res1080p,
        .res1440p, .res2160p, .res4320p
    ]

    var ffmpegScaleFilter: String {
        if self == .automatic {
            return ""  // No scaling for automatic
        }
        return "scale=\(width):\(height):force_original_aspect_ratio=decrease," +
               "pad=\(width):\(height):(ow-iw)/2:(oh-ih)/2"
    }

    func ffmpegScaleFilter(aspectRatio: VideoAspectRatio) -> String {
        if self == .automatic && aspectRatio == .automatic {
            // No scaling at all - preserve original resolution and aspect ratio
            return ""
        }

        if self == .automatic && aspectRatio != .automatic {
            // Only change aspect ratio, preserve resolution
            switch aspectRatio {
            case .fourThree:
                return "scale='iw*min(1,4/3*ih/iw)':'ih*min(1,iw*3/4/ih)'," +
                       "pad='max(iw,ih*4/3)':'max(ih,iw*3/4)':(ow-iw)/2:(oh-ih)/2,setsar=1"
            case .sixteenNine:
                return "scale='iw*min(1,16/9*ih/iw)':'ih*min(1,iw*9/16/ih)'," +
                       "pad='max(iw,ih*16/9)':'max(ih,iw*9/16)':(ow-iw)/2:(oh-ih)/2,setsar=1"
            case .square:
                return "scale='min(iw,ih)':'min(iw,ih)',pad='max(iw,ih)':'max(iw,ih)':(ow-iw)/2:(oh-ih)/2,setsar=1"
            case .automatic:
                return ""
            }
        }

        if aspectRatio == .automatic {
            // Keep original aspect ratio with resolution scaling
            return ffmpegScaleFilter
        }

        // Calculate dimensions based on height and aspect ratio
        let targetHeight = self.height
        let targetWidth: Int

        switch aspectRatio {
        case .fourThree:
            targetWidth = (targetHeight * 4) / 3
        case .sixteenNine:
            targetWidth = (targetHeight * 16) / 9
        case .square:
            targetWidth = targetHeight
        case .automatic:
            targetWidth = self.width
        }

        // Scale and pad to exact aspect ratio
        return "scale=\(targetWidth):\(targetHeight):force_original_aspect_ratio=decrease," +
               "pad=\(targetWidth):\(targetHeight):(ow-iw)/2:(oh-ih)/2,setsar=1"
    }
}

// GIF-specific options
struct AnimatedGIFOptions {
    var fps: Int = 10  // Lower FPS for GIFs
    var width: Int = 480  // Width in pixels
    var loop: Int = 0  // 0 = infinite loop, -1 = no loop
    var usePalette: Bool = true  // Use palette optimization for better colors
}

// Subtitle format options
enum SubtitleFormat: String, CaseIterable {
    case srt = "srt"
    case webvtt = "webvtt"
    case ass = "ass"
    
    var displayName: String {
        switch self {
        case .srt:
            return "SRT"
        case .webvtt:
            return "WebVTT"
        case .ass:
            return "ASS"
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

struct VideoOptions {
    var resolution: VideoResolution = .automatic
    var aspectRatio: VideoAspectRatio = .automatic
    var qualityMode: VideoQualityMode = .constantRateFactor
    var crfQuality: FFmpegQuality = .high
    var crfValue: Double = 23  // Default CRF value (0-51, lower is better)
    var targetBitrate: VideoBitrate = .high
    var customBitrate: String = "5"  // Default 5 Mbps
    var useTwoPassEncoding: Bool = false
    var encoder: VideoEncoder = .x264  // Default to x264
    var preset: VideoPreset = .medium  // Default to medium preset
    var gifOptions: AnimatedGIFOptions = AnimatedGIFOptions()  // GIF-specific settings
    var subtitleFormat: SubtitleFormat = .srt  // Default subtitle format
    var selectedSubtitleIndices: Set<Int> = []  // Selected subtitle stream indices for extraction

    func ffmpegArguments(for format: FFmpegFormat) -> [String] {
        var args: [String] = []

        // Special handling for GIF format
        if format == .gif {
            return ffmpegGIFArguments()
        }

        // Add scale filter for resolution and aspect ratio
        let scaleFilter = resolution.ffmpegScaleFilter(aspectRatio: aspectRatio)
        if !scaleFilter.isEmpty {
            args.append(contentsOf: ["-vf", scaleFilter])
        }

        // Add quality settings based on mode
        switch qualityMode {
        case .constantRateFactor:
            // Use custom CRF value
            if format.supportsCRF {
                args.append(contentsOf: ["-crf", "\(Int(crfValue))"])
                // Only add preset for x264 and x265
                if encoder == .x264 || encoder == .x265 {
                    args.append(contentsOf: ["-preset", preset.rawValue])
                }
            } else {
                // Fallback to quality-based bitrate for codecs that don't support CRF
                let fallbackBitrate = crfValue < 20 ? "10M" : crfValue < 30 ? "5M" : "2.5M"
                args.append(contentsOf: ["-b:v", fallbackBitrate])
            }
        case .bitrate:
            // Use custom bitrate with M suffix for megabits
            let bitrateValue = customBitrate.isEmpty ? "5M" : "\(customBitrate)M"
            args.append(contentsOf: ["-b:v", bitrateValue])
            // Only add preset for x264 and x265
            if encoder == .x264 || encoder == .x265 {
                args.append(contentsOf: ["-preset", preset.rawValue])
            }
        }

        return args
    }

    // Generate FFmpeg arguments specifically for GIF conversion
    func ffmpegGIFArguments() -> [String] {
        var args: [String] = []

        // Build filter chain for GIF
        var filters: [String] = []

        // FPS filter
        filters.append("fps=\(gifOptions.fps)")

        // Scale filter
        filters.append("scale=\(gifOptions.width):-1:flags=lanczos")

        // Apply filter chain
        args.append(contentsOf: ["-vf", filters.joined(separator: ",")])

        // Loop setting
        args.append(contentsOf: ["-loop", "\(gifOptions.loop)"])

        return args
    }

    // Generate arguments for two-pass encoding
    func ffmpegArgumentsForPass(_ pass: Int, for format: FFmpegFormat, logFile: String) -> [String] {
        var args: [String] = []

        // Add scale filter for resolution and aspect ratio
        let scaleFilter = resolution.ffmpegScaleFilter(aspectRatio: aspectRatio)
        if !scaleFilter.isEmpty {
            args.append(contentsOf: ["-vf", scaleFilter])
        }

        // Add bitrate settings
        let bitrateValue = customBitrate.isEmpty ? "5M" : "\(customBitrate)M"
        args.append(contentsOf: ["-b:v", bitrateValue])
        // Only add preset for x264 and x265
        if encoder == .x264 || encoder == .x265 {
            args.append(contentsOf: ["-preset", preset.rawValue])
        }

        // Add pass-specific arguments
        args.append(contentsOf: ["-pass", "\(pass)", "-passlogfile", logFile])

        if pass == 1 {
            // First pass: analysis only, no output needed
            args.append(contentsOf: ["-f", "null"])
        }

        return args
    }
}
