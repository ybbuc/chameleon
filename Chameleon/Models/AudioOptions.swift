//
//  AudioOptions.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import Foundation

enum AudioBitRate: Int, CaseIterable {
    case kbps8 = 8
    case kbps16 = 16
    case kbps32 = 32
    case kbps48 = 48
    case kbps56 = 56
    case kbps64 = 64
    case kbps80 = 80
    case kbps96 = 96
    case kbps112 = 112
    case kbps128 = 128
    case kbps160 = 160
    case kbps192 = 192
    case kbps224 = 224
    case kbps256 = 256
    case kbps320 = 320
    
    var displayName: String {
        return "\(rawValue) kbps"
    }
}

enum AudioChannels: String, CaseIterable {
    case automatic = "auto"
    case mono = "mono"
    case stereo = "stereo"
    
    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .mono: return "Mono"
        case .stereo: return "Stereo"
        }
    }
    
    var channelCount: Int? {
        switch self {
        case .automatic: return nil
        case .mono: return 1
        case .stereo: return 2
        }
    }
}

enum AudioSampleRate: Int, CaseIterable {
    case hz8000 = 8000
    case hz11025 = 11025
    case hz12000 = 12000
    case hz16000 = 16000
    case hz22050 = 22050
    case hz24000 = 24000
    case hz32000 = 32000
    case hz44100 = 44100
    case hz48000 = 48000
    case hz88200 = 88200
    case hz96000 = 96000
    case hz176400 = 176400
    case hz192000 = 192000
    case hz352800 = 352800
    case hz384000 = 384000
    
    var displayName: String {
        return "\(rawValue) Hz"
    }
    
    static var defaultSampleRates: [AudioSampleRate] {
        return [.hz22050, .hz44100, .hz48000, .hz96000]
    }
}

enum AudioSampleSize: Int, CaseIterable {
    case bits16 = 16
    case bits20 = 20
    case bits24 = 24
    case bits32 = 32
    
    var displayName: String {
        return "\(rawValue) bits"
    }
    
}

struct AudioOptions {
    var bitRate: AudioBitRate = .kbps192
    var channels: AudioChannels = .automatic
    var sampleRate: AudioSampleRate = .hz44100
    var sampleSize: AudioSampleSize = .bits16
    var useVariableBitRate: Bool = false
    
    func ffmpegArguments(for format: FFmpegFormat? = nil) -> [String] {
        guard let format = format,
              let config = FormatRegistry.shared.config(for: format) else {
            return []
        }
        
        return config.audioArguments(audioOptions: self)
    }
}