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
    var displayName: String { get }
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
    func codecArguments(for encoder: VideoEncoder?) -> [String]
    func qualityArguments(quality: FFmpegQuality) -> [String]
    func audioArguments(audioOptions: AudioOptions) -> [String]
    func supportedVideoEncoders() -> [VideoEncoder]
}

// MARK: - Default Implementations

// Media format defaults
extension MediaFormatConfig {
    var supportsBitRate: Bool { !isLossless }
    var supportsSampleSize: Bool { isLossless }
    var supportsVariableBitRate: Bool { false }
    var availableSampleRates: [AudioSampleRate] { AudioSampleRate.defaultSampleRates }
    var availableSampleSizes: [AudioSampleSize] { AudioSampleSize.allCases }
    
    // Default implementation for codec arguments with specific encoder
    func codecArguments(for encoder: VideoEncoder?) -> [String] {
        // If no encoder specified or format doesn't support multiple encoders, use default
        return codecArguments()
    }
    
    // Default implementation for supported encoders (empty for formats that don't support encoder selection)
    func supportedVideoEncoders() -> [VideoEncoder] {
        return []
    }
    
    func qualityArguments(quality: FFmpegQuality) -> [String] {
        isVideo ? quality.videoArguments : quality.audioArguments
    }
    
    func audioArguments(audioOptions: AudioOptions) -> [String] {
        var args: [String] = []
        
        // Bit rate (only for lossy formats)
        if supportsBitRate {
            if supportsVariableBitRate && audioOptions.useVariableBitRate {
                // Use the vbrQuality value for VBR encoding
                args.append(contentsOf: ["-q:a", "\(audioOptions.vbrQuality.rawValue)"])
            } else if let bitRateValue = audioOptions.bitRate.value {
                args.append(contentsOf: ["-b:a", "\(bitRateValue)k"])
            }
            // If automatic is selected, we don't specify bit rate and let FFmpeg choose
        }
        
        // Channels (only specify if not automatic)
        if let channelCount = audioOptions.channels.channelCount {
            args.append(contentsOf: ["-ac", "\(channelCount)"])
        }
        
        // Sample rate (only specify if not automatic)
        if let sampleRateValue = audioOptions.sampleRate.value {
            args.append(contentsOf: ["-ar", "\(sampleRateValue)"])
        }
        // If automatic is selected, we don't specify sample rate and let FFmpeg choose
        
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

// NOTE: Video format configs are in VideoFormatConfig.swift
// NOTE: Audio format configs are in AudioFormatConfig.swift  
// NOTE: Image format configs are in ImageFormatConfig.swift
// NOTE: Document format configs can be added in future iterations

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
            .gif: AnimatedGIFConfig(),
            
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
