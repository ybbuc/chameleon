//
//  SubtitleFormatConfig.swift
//  Chameleon
//
//  Created by Jakob Wells on 05.07.25.
//

import Foundation

// MARK: - Subtitle Format Configs

struct SRTConfig: MediaFormatConfig {
    let displayName = "SRT"
    let ffmpegFormat = FFmpegFormat.srt
    let description: String? = "Text-based and universally supported. Lacks advanced styling, but is compact and compatible with almost any player."
    let fileExtension = "srt"
    let isVideo = false
    let isLossless = true
    
    func codecArguments() -> [String] {
        return ["-c:s", "srt"]
    }
    
    func qualityArguments(quality: FFmpegQuality) -> [String] {
        return [] // No quality settings for subtitles
    }
    
    func audioArguments(audioOptions: AudioOptions) -> [String] {
        return [] // No audio for subtitle extraction
    }
}

struct WebVTTConfig: MediaFormatConfig {
    let displayName = "WebVTT"
    let ffmpegFormat = FFmpegFormat.webvtt
    let description: String? = "The modern standard for web video. Text-based and similar to SRT but with added support for styling and metadata. Ideal for HTML5 video."
    let fileExtension = "vtt"
    let isVideo = false
    let isLossless = true
    
    func codecArguments() -> [String] {
        return ["-c:s", "webvtt"]
    }
    
    func qualityArguments(quality: FFmpegQuality) -> [String] {
        return [] // No quality settings for subtitles
    }
    
    func audioArguments(audioOptions: AudioOptions) -> [String] {
        return [] // No audio for subtitle extraction
    }
}

struct ASSConfig: MediaFormatConfig {
    let displayName = "ASS"
    let ffmpegFormat = FFmpegFormat.ass
    let description: String? = "Text-based format with powerful support for custom styling, positioning, and effects. The standard for fansubs and high-quality presentations."
    let fileExtension = "ass"
    let isVideo = false
    let isLossless = true
    
    func codecArguments() -> [String] {
        return ["-c:s", "ass"]
    }
    
    func qualityArguments(quality: FFmpegQuality) -> [String] {
        return [] // No quality settings for subtitles
    }
    
    func audioArguments(audioOptions: AudioOptions) -> [String] {
        return [] // No audio for subtitle extraction
    }
}

struct SSAConfig: MediaFormatConfig {
    let displayName = "SSA"
    let ffmpegFormat = FFmpegFormat.ssa
    let description: String? = "Text-based format with support for styling and positioning. The predecessor to ASS, still widely used for anime subtitles."
    let fileExtension = "ssa"
    let isVideo = false
    let isLossless = true
    
    func codecArguments() -> [String] {
        return ["-c:s", "ssa"]
    }
    
    func qualityArguments(quality: FFmpegQuality) -> [String] {
        return []
    }
    
    func audioArguments(audioOptions: AudioOptions) -> [String] {
        return []
    }
}


struct TTMLConfig: MediaFormatConfig {
    let displayName = "TTML"
    let ffmpegFormat = FFmpegFormat.ttml
    let description: String? = "XML-based subtitle format used in broadcasting and streaming. Supports advanced styling and positioning."
    let fileExtension = "ttml"
    let isVideo = false
    let isLossless = true
    
    func codecArguments() -> [String] {
        return ["-c:s", "ttml"]
    }
    
    func qualityArguments(quality: FFmpegQuality) -> [String] {
        return []
    }
    
    func audioArguments(audioOptions: AudioOptions) -> [String] {
        return []
    }
}

