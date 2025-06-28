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
    case mono = "mono"
    case stereo = "stereo"
    
    var displayName: String {
        switch self {
        case .mono: return "Mono"
        case .stereo: return "Stereo"
        }
    }
    
    var channelCount: Int {
        switch self {
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
    
    static var mp3SampleRates: [AudioSampleRate] {
        return [.hz8000, .hz11025, .hz12000, .hz16000, .hz22050, .hz24000, .hz32000, .hz44100, .hz48000]
    }
    
    static var flacSampleRates: [AudioSampleRate] {
        return allCases
    }
    
    static var defaultSampleRates: [AudioSampleRate] {
        return [.hz22050, .hz44100, .hz48000, .hz96000]
    }
    
    static var aiffSampleRates: [AudioSampleRate] {
        return allCases  // AIFF supports all sample rates we have defined
    }
    
    static var wavSampleRates: [AudioSampleRate] {
        return allCases  // WAV supports all sample rates we have defined
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
    
    static var flacSampleSizes: [AudioSampleSize] {
        return [.bits16, .bits24]
    }
    
    static var alacSampleSizes: [AudioSampleSize] {
        return [.bits16, .bits20, .bits24]
    }
    
    static var aiffSampleSizes: [AudioSampleSize] {
        return [.bits16, .bits24, .bits32]
    }
    
    static var wavSampleSizes: [AudioSampleSize] {
        return [.bits16, .bits24, .bits32]
    }
}

struct AudioOptions {
    var bitRate: AudioBitRate = .kbps192
    var channels: AudioChannels = .stereo
    var sampleRate: AudioSampleRate = .hz44100
    var sampleSize: AudioSampleSize = .bits16
    var useVariableBitRate: Bool = false
    
    func ffmpegArguments(for format: FFmpegFormat? = nil) -> [String] {
        var args: [String] = []
        
        // Bit rate (only for formats that support it, not for lossless formats like FLAC, ALAC, WAV, and AIFF)
        if format != .flac && format != .alac && format != .wav && format != .aiff {
            if useVariableBitRate {
                // Variable bit rate - map bit rate to quality level
                let qualityLevel: String
                switch bitRate.rawValue {
                case ...128:
                    qualityLevel = "4" // Lower quality
                case 129...192:
                    qualityLevel = "2" // Medium quality  
                case 193...256:
                    qualityLevel = "1" // High quality
                default:
                    qualityLevel = "0" // Very high quality
                }
                args.append(contentsOf: ["-q:a", qualityLevel])
            } else {
                // Constant bit rate
                args.append(contentsOf: ["-b:a", "\(bitRate.rawValue)k"])
            }
        }
        
        // Channels
        args.append(contentsOf: ["-ac", "\(channels.channelCount)"])
        
        // Sample rate
        args.append(contentsOf: ["-ar", "\(sampleRate.rawValue)"])
        
        // Sample size (only for lossless formats like FLAC, ALAC, WAV, and AIFF)
        if format == .flac || format == .alac {
            args.append(contentsOf: ["-sample_fmt", "s\(sampleSize.rawValue)"])
        } else if format == .wav {
            // WAV uses little-endian format
            args.append(contentsOf: ["-sample_fmt", "s\(sampleSize.rawValue)le"])
        } else if format == .aiff {
            // AIFF uses big-endian format
            args.append(contentsOf: ["-sample_fmt", "s\(sampleSize.rawValue)be"])
        }
        
        return args
    }
}