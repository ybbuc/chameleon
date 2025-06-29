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
