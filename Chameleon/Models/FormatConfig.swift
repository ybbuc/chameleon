 //
//  FormatConfig.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import Foundation

protocol FormatConfig {
    var format: FFmpegFormat { get }
    var displayName: String { get }
    var description: String? { get }
    var fileExtension: String { get }
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

// Default implementations for common patterns
extension FormatConfig {
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

struct MP4Config: FormatConfig {
    let format = FFmpegFormat.mp4
    let displayName = "MP4 Video"
    let description: String? = nil
    let fileExtension = "mp4"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

struct MOVConfig: FormatConfig {
    let format = FFmpegFormat.mov
    let displayName = "QuickTime Movie"
    let description: String? = nil
    let fileExtension = "mov"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

struct AVIConfig: FormatConfig {
    let format = FFmpegFormat.avi
    let displayName = "AVI Video"
    let description: String? = nil
    let fileExtension = "avi"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "libmp3lame"]
    }
}

struct MKVConfig: FormatConfig {
    let format = FFmpegFormat.mkv
    let displayName = "Matroska Video"
    let description: String? = nil
    let fileExtension = "mkv"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}
  
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libvpx-vp9", "-c:a", "libvorbis"]
    }
}

struct FLVConfig: FormatConfig {
    let format = FFmpegFormat.flv
    let displayName = "Flash Video"
    let description: String? = nil
    let fileExtension = "flv"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

struct WMVConfig: FormatConfig {
    let format = FFmpegFormat.wmv
    let displayName = "Windows Media Video"
    let description: String? = nil
    let fileExtension = "wmv"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "wmv2", "-c:a", "wmav2"]
    }
}

struct M4VConfig: FormatConfig {
    let format = FFmpegFormat.m4v
    let displayName = "iTunes Video"
    let description: String? = nil
    let fileExtension = "m4v"
    let isVideo = true
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:v", "libx264", "-c:a", "aac"]
    }
}

// MARK: - Audio Format Configurations

struct MP3Config: FormatConfig {
    let format = FFmpegFormat.mp3
    let displayName = "MP3 Audio"
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

struct AACConfig: FormatConfig {
    let format = FFmpegFormat.aac
    let displayName = "AAC Audio"
    let description: String? = "Lossy, though less than MP3. The files are very compact, and are generally well supported by most applications."
    let fileExtension = "m4a"
    let isVideo = false
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:a", "aac"]
    }
}

struct WAVConfig: FormatConfig {
    let format = FFmpegFormat.wav
    let displayName = "WAV Audio"
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

struct FLACConfig: FormatConfig {
    let format = FFmpegFormat.flac
    let displayName = "FLAC Audio"
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

struct ALACConfig: FormatConfig {
    let format = FFmpegFormat.alac
    let displayName = "ALAC Audio"
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

struct OGGConfig: FormatConfig {
    let format = FFmpegFormat.ogg
    let displayName = "Ogg Vorbis"
    let description: String? = "Lossy, with quality often better than MP3 at similar bitrates. While the files are compact, it's not as universally supported as MP3 or AAC."
    let fileExtension = "ogg"
    let isVideo = false
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:a", "libvorbis"]
    }
}

struct WMAConfig: FormatConfig {
    let format = FFmpegFormat.wma
    let displayName = "Windows Media Audio"
    let description: String? = "Lossy, with quality comparable to MP3. It's well-supported on Windows but less common on other platforms."
    let fileExtension = "wma"
    let isVideo = false
    let isLossless = false
    
    func codecArguments() -> [String] {
        return ["-c:a", "wmav2"]
    }
}

struct AIFFConfig: FormatConfig {
    let format = FFmpegFormat.aiff
    let displayName = "AIFF Audio"
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

// MARK: - Format Registry

class FormatRegistry {
    static let shared = FormatRegistry()
    
    private let configs: [FFmpegFormat: FormatConfig]
    
    private init() {
        configs = [
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
    
    func config(for format: FFmpegFormat) -> FormatConfig? {
        return configs[format]
    }
    
    func allConfigs() -> [FormatConfig] {
        return Array(configs.values)
    }
    
    func videoConfigs() -> [FormatConfig] {
        return configs.values.filter { $0.isVideo }
    }
    
    func audioConfigs() -> [FormatConfig] {
        return configs.values.filter { !$0.isVideo }
    }
    
    func losslessConfigs() -> [FormatConfig] {
        return configs.values.filter { $0.isLossless }
    }
    
    func lossyConfigs() -> [FormatConfig] {
        return configs.values.filter { !$0.isLossless }
    }
}
