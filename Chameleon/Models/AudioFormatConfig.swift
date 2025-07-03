//
//  AudioFormatConfig.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import Foundation

// MARK: - Audio Format Configurations

struct MP3Config: MediaFormatConfig {
    let displayName = "MP3"
    let ffmpegFormat = FFmpegFormat.mp3
    let description: String? = "Lossy, but the files are very compact and can be played in almost any application."
    let fileExtension = "mp3"
    let isVideo = false
    let isLossless = false
    let supportsVariableBitRate = true

    var availableSampleRates: [AudioSampleRate] {
        return [.automatic, .hz8000, .hz11025, .hz12000, .hz16000, .hz22050, .hz24000, .hz32000, .hz44100, .hz48000]
    }

    func codecArguments() -> [String] {
        return ["-c:a", "libmp3lame"]
    }
}

struct AACConfig: MediaFormatConfig {
    let displayName = "AAC"
    let ffmpegFormat = FFmpegFormat.aac
    let description: String? = "Lossy, though less than MP3. The files are very compact, " +
                               "and are generally well supported by most applications."
    let fileExtension = "m4a"
    let isVideo = false
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:a", "aac"]
    }
}

struct WAVConfig: MediaFormatConfig {
    let displayName = "WAV"
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
    let displayName = "FLAC"
    let ffmpegFormat = FFmpegFormat.flac
    let description: String? = "Lossless, but the files are quite large. " +
                               "It's popular among audiophiles, but playback support is limited."
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
    let displayName = "ALAC"
    let ffmpegFormat = FFmpegFormat.alac
    let description: String? = "Lossless, but the files are quite large. " +
                               "Standard on Apple platforms, but less universal elsewhere."
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
    let displayName = "OGG"
    let ffmpegFormat = FFmpegFormat.ogg
    let description: String? = "Lossy, with quality often better than MP3 at similar bitrates. " +
                               "While compact, it's not as universal as MP3 or AAC."
    let fileExtension = "ogg"
    let isVideo = false
    let isLossless = false

    func codecArguments() -> [String] {
        return ["-c:a", "libvorbis"]
    }
}

struct WMAConfig: MediaFormatConfig {
    let displayName = "WMA"
    let ffmpegFormat = FFmpegFormat.wma
    let description: String? = "Lossy, with quality comparable to MP3. " +
                               "It's well-supported on Windows but less common on other platforms."
    let fileExtension = "wma"
    let isVideo = false
    let isLossless = false

    var availableSampleRates: [AudioSampleRate] {
        // WMA v2 has limited sample rate support
        return [.automatic, .hz22050, .hz44100, .hz48000]
    }

    func codecArguments() -> [String] {
        return ["-c:a", "wmav2"]
    }
}

struct AIFFConfig: MediaFormatConfig {
    let displayName = "AIFF"
    let ffmpegFormat = FFmpegFormat.aiff
    let description: String? = "Lossless, but the files are quite large. " +
                               "Standard on Apple platforms, but less common than WAV elsewhere."
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
