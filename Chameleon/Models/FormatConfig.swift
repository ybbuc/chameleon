 //
//  FormatConfig.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import Foundation

// MARK: - Base Format Config Protocol

protocol FormatConfig {
    var description: String? { get }
    var fileExtension: String { get }
}

// MARK: - Media Format Config Protocol

protocol MediaFormatConfig: FormatConfig {
    var ffmpegFormat: FFmpegFormat { get }
    var isVideo: Bool { get }
    var isLossless: Bool { get }
    
    // Audio-specific properties
    var supportsBitRate: Bool { get }
    var supportsSampleSize: Bool { get }
    var supportsVariableBitRate: Bool { get }
    var availableSampleRates: [AudioSampleRate] { get }
    var availableSampleSizes: [AudioSampleSize] { get }
    
    // FFmpeg arguments
    func codecArguments() -> [String]
    func qualityArguments(quality: FFmpegQuality) -> [String]
    func audioArguments(audioOptions: AudioOptions) -> [String]
}

// MARK: - Default Implementations

// Media format defaults
extension MediaFormatConfig {
    var supportsBitRate: Bool { !isLossless }
    var supportsSampleSize: Bool { isLossless }
    var supportsVariableBitRate: Bool { false }
    var availableSampleRates: [AudioSampleRate] { AudioSampleRate.defaultSampleRates }
    var availableSampleSizes: [AudioSampleSize] { AudioSampleSize.allCases }
    
    func qualityArguments(quality: FFmpegQuality) -> [String] {
        isVideo ? quality.videoArguments : quality.audioArguments
    }
    
    func audioArguments(audioOptions: AudioOptions) -> [String] {
        var args: [String] = []
        
        // Bit rate (only for lossy formats)
        if supportsBitRate {
            if supportsVariableBitRate && audioOptions.useVariableBitRate {
                let qualityLevel: String
                switch audioOptions.bitRate.rawValue {
                case ...128: qualityLevel = "4"
                case 129...192: qualityLevel = "2"
                case 193...256: qualityLevel = "1"
                default: qualityLevel = "0"
                }
                args.append(contentsOf: ["-q:a", qualityLevel])
            } else {
                args.append(contentsOf: ["-b:a", "\(audioOptions.bitRate.rawValue)k"])
            }
        }
        
        // Channels
        args.append(contentsOf: ["-ac", "\(audioOptions.channels.channelCount)"])
        
        // Sample rate
        args.append(contentsOf: ["-ar", "\(audioOptions.sampleRate.rawValue)"])
        
        // Sample size (only for lossless formats)
        if supportsSampleSize {
            args.append(contentsOf: sampleFormatArguments(sampleSize: audioOptions.sampleSize))
        }
        
        return args
    }
    
    func sampleFormatArguments(sampleSize: AudioSampleSize) -> [String] {
        return ["-sample_fmt", "s\(sampleSize.rawValue)"]
    }
}

// MARK: - Video Format Configurations

struct MP4Config: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.mp4
    let description: String? = nil
    let fileExtension = "mp4"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

struct MOVConfig: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.mov
    let description: String? = nil
    let fileExtension = "mov"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

struct AVIConfig: MediaFormatConfig {
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
    let ffmpegFormat = FFmpegFormat.mkv
    let description: String? = nil
    let fileExtension = "mkv"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

struct WebMConfig: MediaFormatConfig {
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
    let ffmpegFormat = FFmpegFormat.m4v
    let description: String? = nil
    let fileExtension = "m4v"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

// MARK: - Audio Format Configurations

struct MP3Config: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.mp3
    let description: String? = "Lossy, but the files are very compact and can be played in almost any application."
    let fileExtension = "mp3"
    let isVideo = false
    let isLossless = false
    let supportsVariableBitRate = true
    
    var availableSampleRates: [AudioSampleRate] {
        return [.hz8000, .hz11025, .hz12000, .hz16000, .hz22050, .hz24000, .hz32000, .hz44100, .hz48000]
    }
    
    func codecArguments() -> [String] {
        return ["-c:a", "libmp3lame"]
    }
}

struct AACConfig: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.aac
    let description: String? = "Lossy, though less than MP3. The files are very compact, and are generally well supported by most applications."
    let fileExtension = "m4a"
    let isVideo = false
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:a", "aac"]
    }
}

struct WAVConfig: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.wav
    let description: String? = "Lossless, but the files are enormous. They can be played by almost any application."
    let fileExtension = "wav"
    let isVideo = false
    let isLossless = true
    
    var availableSampleRates: [AudioSampleRate] {
        return AudioSampleRate.allCases
    }
    
    var availableSampleSizes: [AudioSampleSize] {
        return [.bits16, .bits24, .bits32]
    }
    
    func codecArguments() -> [String] {
        return ["-c:a", "pcm_s16le"]
    }
    
    func sampleFormatArguments(sampleSize: AudioSampleSize) -> [String] {
        return ["-sample_fmt", "s\(sampleSize.rawValue)le"]
    }
}

struct FLACConfig: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.flac
    let description: String? = "Lossless, but the files are quite large. It's popular among audiophiles, but playback is supported in few audio players."
    let fileExtension = "flac"
    let isVideo = false
    let isLossless = true
    
    var availableSampleRates: [AudioSampleRate] {
        return AudioSampleRate.allCases
    }
    
    var availableSampleSizes: [AudioSampleSize] {
        return [.bits16, .bits24]
    }
    
    func codecArguments() -> [String] {
        return ["-c:a", "flac"]
    }
}

struct ALACConfig: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.alac
    let description: String? = "Lossless, but the files are quite large. Standard on Apple platforms, but less universal elsewhere."
    let fileExtension = "m4a"
    let isVideo = false
    let isLossless = true
    
    var availableSampleRates: [AudioSampleRate] {
        return AudioSampleRate.allCases
    }
    
    var availableSampleSizes: [AudioSampleSize] {
        return [.bits16, .bits20, .bits24]
    }
    
    func codecArguments() -> [String] {
        return ["-c:a", "alac"]
    }
}

struct OGGConfig: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.ogg
    let description: String? = "Lossy, with quality often better than MP3 at similar bitrates. While the files are compact, it's not as universally supported as MP3 or AAC."
    let fileExtension = "ogg"
    let isVideo = false
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:a", "libvorbis"]
    }
}

struct WMAConfig: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.wma
    let description: String? = "Lossy, with quality comparable to MP3. It's well-supported on Windows but less common on other platforms."
    let fileExtension = "wma"
    let isVideo = false
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:a", "wmav2"]
    }
}

struct AIFFConfig: MediaFormatConfig {
    let ffmpegFormat = FFmpegFormat.aiff
    let description: String? = "Lossless, but the files are quite large. Standard on Apple platforms, but less common than WAV elsewhere."
    let fileExtension = "aiff"
    let isVideo = false
    let isLossless = true
    
    var availableSampleRates: [AudioSampleRate] {
        return AudioSampleRate.allCases
    }
    
    var availableSampleSizes: [AudioSampleSize] {
        return [.bits16, .bits24, .bits32]
    }
    
    func codecArguments() -> [String] {
        return ["-f", "aiff"]
    }
    
    func sampleFormatArguments(sampleSize: AudioSampleSize) -> [String] {
        return ["-sample_fmt", "s\(sampleSize.rawValue)be"]
    }
}

// NOTE: Document and Image format configs can be added in future iterations
// For now, we're focusing on the media format system

// MARK: - Format Registry

class FormatRegistry {
    static let shared = FormatRegistry()
    
    private let mediaConfigs: [FFmpegFormat: MediaFormatConfig]
    
    private init() {
        mediaConfigs = [
            // Video formats
            .mp4: MP4Config(),
            .mov: MOVConfig(),
            .avi: AVIConfig(),
            .mkv: MKVConfig(),
            .webm: WebMConfig(),
            .flv: FLVConfig(),
            .wmv: WMVConfig(),
            .m4v: M4VConfig(),
            
            // Audio formats
            .mp3: MP3Config(),
            .aac: AACConfig(),
            .wav: WAVConfig(),
            .flac: FLACConfig(),
            .alac: ALACConfig(),
            .ogg: OGGConfig(),
            .wma: WMAConfig(),
            .aiff: AIFFConfig()
        ]
    }
    
    // Media format methods (for backward compatibility)
    func config(for format: FFmpegFormat) -> MediaFormatConfig? {
        return mediaConfigs[format]
    }
    
    func allConfigs() -> [MediaFormatConfig] {
        return Array(mediaConfigs.values)
    }
    
    func videoConfigs() -> [MediaFormatConfig] {
        return mediaConfigs.values.filter { $0.isVideo }
    }
    
    func audioConfigs() -> [MediaFormatConfig] {
        return mediaConfigs.values.filter { !$0.isVideo }
    }
    
    func losslessConfigs() -> [MediaFormatConfig] {
        return mediaConfigs.values.filter { $0.isLossless }
    }
    
    func lossyConfigs() -> [MediaFormatConfig] {
        return mediaConfigs.values.filter { !$0.isLossless }
    }
    
    // TODO: Document and image format methods can be added in future iterations
}
