//
//  TTSFormatConfig.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import Foundation

// MARK: - TTS Format Configuration Protocol

protocol TTSFormatConfig: FormatConfig {
    var displayName: String { get }
    var audioCodec: String { get }
    var supportsMultipleVoices: Bool { get }
    var defaultRate: Int { get }
    var minRate: Int { get }
    var maxRate: Int { get }
}

// MARK: - TTS Format Configurations

struct AIFFTTSConfig: TTSFormatConfig {
    let displayName = "AIFF"
    let description: String? = "Lossless, but the files are quite large. " +
                               "Standard on Apple platforms, but less common than WAV elsewhere."
    let fileExtension = "aiff"
    let audioCodec = "lpcm"
    let supportsMultipleVoices = true
    let defaultRate = 180
    let minRate = 120
    let maxRate = 300
}

struct M4ATTSConfig: TTSFormatConfig {
    let displayName = "M4A"
    let description: String? = "Lossy, though less than MP3. The files are very compact, " +
                               "and are generally well supported by most applications."
    let fileExtension = "m4a"
    let audioCodec = "aac"
    let supportsMultipleVoices = true
    let defaultRate = 180
    let minRate = 120
    let maxRate = 300
}

struct WAVTTSConfig: TTSFormatConfig {
    let displayName = "WAV"
    let description: String? = "Lossless, but the files are enormous. They can be played by almost any application."
    let fileExtension = "wav"
    let audioCodec = "lpcm"
    let supportsMultipleVoices = true
    let defaultRate = 180
    let minRate = 120
    let maxRate = 300
}

struct CAFTTSConfig: TTSFormatConfig {
    let displayName = "CAF"
    let description: String? = "Apple's flexible audio container format. Supports both lossy and lossless codecs."
    let fileExtension = "caf"
    let audioCodec = "aac"
    let supportsMultipleVoices = true
    let defaultRate = 180
    let minRate = 120
    let maxRate = 300
}

// MARK: - Format Registry Extension

extension FormatRegistry {
    private static let ttsConfigs: [TTSFormat: TTSFormatConfig] = [
        .aiff: AIFFTTSConfig(),
        .m4a: M4ATTSConfig(),
        .wav: WAVTTSConfig(),
        .caf: CAFTTSConfig()
    ]

    func config(for format: TTSFormat) -> TTSFormatConfig? {
        return Self.ttsConfigs[format]
    }
}
