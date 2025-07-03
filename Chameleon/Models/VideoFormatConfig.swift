//
//  VideoFormatConfig.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import Foundation

// CRF support information for different codecs
enum VideoCodecCRFSupport {
    case supported(min: Int, max: Int, default: Int)
    case notSupported

    static func forCodec(_ codec: String) -> VideoCodecCRFSupport {
        switch codec {
        case "libx264":
            return .supported(min: 0, max: 51, default: 23)
        case "libx265":
            return .supported(min: 0, max: 51, default: 28)
        case "libvpx", "libvpx-vp9":
            return .supported(min: 0, max: 63, default: 31)
        case "libaom-av1":
            return .supported(min: 0, max: 63, default: 30)
        default:
            return .notSupported
        }
    }
}

struct MP4Config: MediaFormatConfig {
    let displayName = "MP4"
    let ffmpegFormat = FFmpegFormat.mp4
    let description: String? = nil
    let fileExtension = "mp4"
    let isVideo = true
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }

    func codecArguments(for encoder: VideoEncoder?) -> [String] {
        let videoEncoder = encoder?.encoderName ?? "libx264"
        return ["-c:v", videoEncoder, "-c:a", "aac"]
    }

    func supportedVideoEncoders() -> [VideoEncoder] {
        return [.x264, .x265]
    }
}

struct MOVConfig: MediaFormatConfig {
    let displayName = "MOV"
    let ffmpegFormat = FFmpegFormat.mov
    let description: String? = nil
    let fileExtension = "mov"
    let isVideo = true
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }

    func codecArguments(for encoder: VideoEncoder?) -> [String] {
        let videoEncoder = encoder?.encoderName ?? "libx264"
        return ["-c:v", videoEncoder, "-c:a", "aac"]
    }

    func supportedVideoEncoders() -> [VideoEncoder] {
        return [.x264, .x265]
    }
}

struct AVIConfig: MediaFormatConfig {
    let displayName = "AVI"
    let ffmpegFormat = FFmpegFormat.avi
    let description: String? = nil
    let fileExtension = "avi"
    let isVideo = true
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "libmp3lame"]
    }
}

struct MKVConfig: MediaFormatConfig {
    let displayName = "MKV"
    let ffmpegFormat = FFmpegFormat.mkv
    let description: String? = nil
    let fileExtension = "mkv"
    let isVideo = true
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }

    func codecArguments(for encoder: VideoEncoder?) -> [String] {
        let videoEncoder = encoder?.encoderName ?? "libx264"
        return ["-c:v", videoEncoder, "-c:a", "aac"]
    }

    func supportedVideoEncoders() -> [VideoEncoder] {
        return [.x264, .x265]
    }
}

struct WebMConfig: MediaFormatConfig {
    let displayName = "WebM"
    let ffmpegFormat = FFmpegFormat.webm
    let description: String? = nil
    let fileExtension = "webm"
    let isVideo = true
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:v", "libvpx-vp9", "-c:a", "libvorbis"]
    }
}

struct FLVConfig: MediaFormatConfig {
    let displayName = "FLV"
    let ffmpegFormat = FFmpegFormat.flv
    let description: String? = nil
    let fileExtension = "flv"
    let isVideo = true
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

struct WMVConfig: MediaFormatConfig {
    let displayName = "WMV"
    let ffmpegFormat = FFmpegFormat.wmv
    let description: String? = nil
    let fileExtension = "wmv"
    let isVideo = true
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:v", "wmv2", "-c:a", "wmav2"]
    }
}

struct M4VConfig: MediaFormatConfig {
    let displayName = "M4V"
    let ffmpegFormat = FFmpegFormat.m4v
    let description: String? = nil
    let fileExtension = "m4v"
    let isVideo = true
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

struct AnimatedGIFConfig: MediaFormatConfig {
    let displayName = "GIF"
    let ffmpegFormat = FFmpegFormat.gif
    let description: String? = ""
    let fileExtension = "gif"
    let isVideo = true
    let isLossless = true  // GIF uses lossless compression but limited colors

    func codecArguments() -> [String] {
        // GIF doesn't use video codecs in the traditional sense
        return []
    }

    func qualityArguments(quality: FFmpegQuality) -> [String] {
        // Override quality arguments for GIF
        return []
    }
}
