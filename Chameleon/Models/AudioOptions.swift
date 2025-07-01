//
//  AudioOptions.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import Foundation

enum AudioBitRate: CaseIterable {
    case automatic
    case kbps8
    case kbps16
    case kbps32
    case kbps48
    case kbps56
    case kbps64
    case kbps80
    case kbps96
    case kbps112
    case kbps128
    case kbps160
    case kbps192
    case kbps224
    case kbps256
    case kbps320
    
    var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        default:
            return "\(value!)"
        }
    }
    
    var value: Int? {
        switch self {
        case .automatic: return nil
        case .kbps8: return 8
        case .kbps16: return 16
        case .kbps32: return 32
        case .kbps48: return 48
        case .kbps56: return 56
        case .kbps64: return 64
        case .kbps80: return 80
        case .kbps96: return 96
        case .kbps112: return 112
        case .kbps128: return 128
        case .kbps160: return 160
        case .kbps192: return 192
        case .kbps224: return 224
        case .kbps256: return 256
        case .kbps320: return 320
        }
    }
}

enum MP3VBRQuality: Int, CaseIterable {
    case q9 = 9  // ~65 kbps
    case q8 = 8  // ~85 kbps
    case q7 = 7  // ~100 kbps
    case q6 = 6  // ~115 kbps
    case q5 = 5  // ~130 kbps
    case q4 = 4  // ~165 kbps
    case q3 = 3  // ~175 kbps
    case q2 = 2  // ~190 kbps
    case q1 = 1  // ~225 kbps
    case q0 = 0  // ~245 kbps
    
    var displayName: String {
        switch self {
        case .q9: return "~65"
        case .q8: return "~85"
        case .q7: return "~100"
        case .q6: return "~115"
        case .q5: return "~130"
        case .q4: return "~165"
        case .q3: return "~175"
        case .q2: return "~190"
        case .q1: return "~225"
        case .q0: return "~245"
        }
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

enum AudioSampleRate: CaseIterable {
    case automatic
    case hz8000
    case hz11025
    case hz12000
    case hz16000
    case hz22050
    case hz24000
    case hz32000
    case hz44100
    case hz48000
    case hz88200
    case hz96000
    case hz176400
    case hz192000
    case hz352800
    case hz384000
    
    var displayName: String {
        switch self {
        case .automatic:
            return "Automatic"
        default:
            return "\(value!)"
        }
    }
    
    var value: Int? {
        switch self {
        case .automatic: return nil
        case .hz8000: return 8000
        case .hz11025: return 11025
        case .hz12000: return 12000
        case .hz16000: return 16000
        case .hz22050: return 22050
        case .hz24000: return 24000
        case .hz32000: return 32000
        case .hz44100: return 44100
        case .hz48000: return 48000
        case .hz88200: return 88200
        case .hz96000: return 96000
        case .hz176400: return 176400
        case .hz192000: return 192000
        case .hz352800: return 352800
        case .hz384000: return 384000
        }
    }
    
    static var defaultSampleRates: [AudioSampleRate] {
        return [.automatic, .hz22050, .hz44100, .hz48000, .hz96000]
    }
}

enum AudioSampleSize: Int, CaseIterable {
    case bits16 = 16
    case bits20 = 20
    case bits24 = 24
    case bits32 = 32
    
    var displayName: String {
        return "\(rawValue)"
    }
    
}

struct AudioOptions {
    var bitRate: AudioBitRate = .automatic
    var channels: AudioChannels = .automatic
    var sampleRate: AudioSampleRate = .automatic
    var sampleSize: AudioSampleSize = .bits16
    var useVariableBitRate: Bool = false
    var vbrQuality: MP3VBRQuality = .q2  // Default to 190 kbps avg
    
    func ffmpegArguments(for format: FFmpegFormat? = nil) -> [String] {
        guard let format = format,
              let config = FormatRegistry.shared.config(for: format) else {
            return []
        }
        
        return config.audioArguments(audioOptions: self)
    }
}
