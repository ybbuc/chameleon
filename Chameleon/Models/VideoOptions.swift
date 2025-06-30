//
//  VideoOptions.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import Foundation

enum VideoResolution: String, CaseIterable {
    case res480p = "480p"
    case res576p = "576p"
    case res720p = "720p"
    case res1080p = "1080p"
    case res1440p = "1440p"
    case res2160p = "2160p"
    case res4320p = "4320p"
    
    var displayName: String {
        return rawValue
    }
    
    var height: Int {
        switch self {
        case .res480p: return 480
        case .res576p: return 576
        case .res720p: return 720
        case .res1080p: return 1080
        case .res1440p: return 1440
        case .res2160p: return 2160
        case .res4320p: return 4320
        }
    }
    
    var width: Int {
        switch self {
        case .res480p: return 854    // 16:9
        case .res576p: return 1024   // 16:9
        case .res720p: return 1280   // 16:9
        case .res1080p: return 1920  // 16:9
        case .res1440p: return 2560  // 16:9
        case .res2160p: return 3840  // 16:9 (4K)
        case .res4320p: return 7680  // 16:9 (8K)
        }
    }
    
    var ffmpegScaleFilter: String {
        return "scale=\(width):\(height):force_original_aspect_ratio=decrease,pad=\(width):\(height):(ow-iw)/2:(oh-ih)/2"
    }
}

struct VideoOptions {
    var resolution: VideoResolution = .res1080p
    var quality: FFmpegQuality = .high
    
    func ffmpegArguments(for format: FFmpegFormat) -> [String] {
        var args: [String] = []
        
        // Add scale filter for resolution
        args.append(contentsOf: ["-vf", resolution.ffmpegScaleFilter])
        
        // Add quality settings
        args.append(contentsOf: quality.videoArguments)
        
        return args
    }
}