//
//  MediaInfoWrapper.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//
//  Wrapper for MediaInfoLib library to get media file information
//

import Foundation

class MediaInfoWrapper {
    typealias MediaInfoHandle = OpaquePointer
    
    // Function pointers for MediaInfoLib
    private typealias MediaInfo_New = @convention(c) () -> MediaInfoHandle?
    private typealias MediaInfo_Delete = @convention(c) (MediaInfoHandle?) -> Void
    private typealias MediaInfo_Open = @convention(c) (MediaInfoHandle?, UnsafePointer<CChar>?) -> Int
    private typealias MediaInfo_Close = @convention(c) (MediaInfoHandle?) -> Void
    private typealias MediaInfo_Get = @convention(c) (MediaInfoHandle?, Int32, Int, UnsafePointer<CChar>?, Int32, Int32) -> UnsafePointer<CChar>?
    private typealias MediaInfo_Option = @convention(c) (MediaInfoHandle?, UnsafePointer<CChar>?, UnsafePointer<CChar>?) -> UnsafePointer<CChar>?
    
    // Stream kinds
    private enum StreamKind: Int32 {
        case general = 0
        case video = 1
        case audio = 2
        case text = 3
        case other = 4
        case image = 5
        case menu = 6
    }
    
    // Info kinds
    private enum InfoKind: Int32 {
        case name = 0
        case text = 1
        case measure = 2
        case options = 3
        case nameText = 4
        case measureText = 5
        case info = 6
        case howTo = 7
    }
    
    private let dylib: UnsafeMutableRawPointer
    private let mediaInfo_New: MediaInfo_New
    private let mediaInfo_Delete: MediaInfo_Delete
    private let mediaInfo_Open: MediaInfo_Open
    private let mediaInfo_Close: MediaInfo_Close
    private let mediaInfo_Get: MediaInfo_Get
    private let mediaInfo_Option: MediaInfo_Option
    
    init() throws {
        // Get the path to the bundled MediaInfoLib in Frameworks folder
        guard let frameworksPath = Bundle.main.privateFrameworksPath else {
            throw MediaInfoError.libraryNotFound
        }
        
        let dylibPath = (frameworksPath as NSString).appendingPathComponent("libmediainfo.dylib")
        
        // Load the dynamic library
        guard let handle = dlopen(dylibPath, RTLD_NOW) else {
            let error = String(cString: dlerror())
            throw MediaInfoError.loadFailed(error)
        }
        
        self.dylib = handle
        
        // Load function pointers - Note: Using ANSI versions (with 'A' suffix)
        guard let newFunc = dlsym(handle, "MediaInfoA_New") else {
            throw MediaInfoError.symbolNotFound("MediaInfoA_New")
        }
        self.mediaInfo_New = unsafeBitCast(newFunc, to: MediaInfo_New.self)
        
        guard let deleteFunc = dlsym(handle, "MediaInfoA_Delete") else {
            throw MediaInfoError.symbolNotFound("MediaInfoA_Delete")
        }
        self.mediaInfo_Delete = unsafeBitCast(deleteFunc, to: MediaInfo_Delete.self)
        
        guard let openFunc = dlsym(handle, "MediaInfoA_Open") else {
            throw MediaInfoError.symbolNotFound("MediaInfoA_Open")
        }
        self.mediaInfo_Open = unsafeBitCast(openFunc, to: MediaInfo_Open.self)
        
        guard let closeFunc = dlsym(handle, "MediaInfoA_Close") else {
            throw MediaInfoError.symbolNotFound("MediaInfoA_Close")
        }
        self.mediaInfo_Close = unsafeBitCast(closeFunc, to: MediaInfo_Close.self)
        
        guard let getFunc = dlsym(handle, "MediaInfoA_Get") else {
            throw MediaInfoError.symbolNotFound("MediaInfoA_Get")
        }
        self.mediaInfo_Get = unsafeBitCast(getFunc, to: MediaInfo_Get.self)
        
        guard let optionFunc = dlsym(handle, "MediaInfoA_Option") else {
            throw MediaInfoError.symbolNotFound("MediaInfoA_Option")
        }
        self.mediaInfo_Option = unsafeBitCast(optionFunc, to: MediaInfo_Option.self)
    }
    
    deinit {
        dlclose(dylib)
    }
    
    func getFileInfo(url: URL) throws -> MediaFileInfo {
        print("🔍 Using MediaInfoLib to analyze: \(url.lastPathComponent)")
        
        // Create MediaInfo instance
        guard let handle = mediaInfo_New() else {
            throw MediaInfoError.initializationFailed
        }
        
        defer {
            mediaInfo_Delete(handle)
        }
        
        // Check if file exists first
        let fileExists = FileManager.default.fileExists(atPath: url.path)
        print("  📁 File exists: \(fileExists)")
        print("  📍 File path: \(url.path)")
        
        // Open the file
        let result = url.path.withCString { path in
            mediaInfo_Open(handle, path)
        }
        
        print("  🔢 MediaInfo_Open result: \(result)")
        
        guard result > 0 else {
            print("  ❌ MediaInfo failed to open file: \(url.path)")
            print("  🔍 Trying to get error info...")
            
            // Try to get more information about why it failed
            if let errorInfo = mediaInfo_Option(handle, "Info_Version", "") {
                print("  MediaInfo version: \(String(cString: errorInfo))")
            }
            
            // Try to get supported formats
            if let formats = mediaInfo_Option(handle, "Info_OutputFormats", "") {
                print("  Supported output formats: \(String(cString: formats))")
            }
            
            throw MediaInfoError.openFailed(url.path)
        }
        
        defer {
            mediaInfo_Close(handle)
        }
        
        // Get format name
        let formatName = getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "Format")
        print("  📊 Format: \(formatName ?? "unknown")")
        
        // Check for video streams
        let videoStreamCount = getInt(handle: handle, streamKind: .video, streamNumber: 0, parameter: "StreamCount") ?? 0
        let hasVideo = videoStreamCount > 0
        print("  📹 Video streams: \(videoStreamCount)")
        
        // Check for audio streams
        let audioStreamCount = getInt(handle: handle, streamKind: .audio, streamNumber: 0, parameter: "StreamCount") ?? 0
        let hasAudio = audioStreamCount > 0
        print("  🔊 Audio streams: \(audioStreamCount)")
        
        // Get video codec if present
        let videoCodec = hasVideo ? getString(handle: handle, streamKind: .video, streamNumber: 0, parameter: "Format") : nil
        
        // Get audio codec if present
        let audioCodec = hasAudio ? getString(handle: handle, streamKind: .audio, streamNumber: 0, parameter: "Format") : nil
        
        // Get duration in seconds
        let durationMs = getDouble(handle: handle, streamKind: .general, streamNumber: 0, parameter: "Duration")
        let duration = durationMs.map { $0 / 1000.0 } // Convert ms to seconds
        
        // Get audio properties
        let audioBitDepth = hasAudio ? getInt(handle: handle, streamKind: .audio, streamNumber: 0, parameter: "BitDepth") : nil
        let audioSampleRate = hasAudio ? getInt(handle: handle, streamKind: .audio, streamNumber: 0, parameter: "SamplingRate") : nil
        let audioChannels = hasAudio ? getInt(handle: handle, streamKind: .audio, streamNumber: 0, parameter: "Channels") : nil
        
        if hasAudio {
            print("  🎵 Audio properties:")
            print("    - Codec: \(audioCodec ?? "unknown")")
            print("    - Bit depth: \(audioBitDepth?.description ?? "not detected")")
            print("    - Sample rate: \(audioSampleRate?.description ?? "not detected") Hz")
            print("    - Channels: \(audioChannels?.description ?? "not detected")")
            
            // Debug: Try to get all available audio parameters
            print("  🔍 Debug - Available audio info:")
            let debugParams = ["Format", "CodecID", "BitRate", "SamplingRate", "BitDepth", 
                             "Resolution", "BitDepth_Detected", "Channels", "ChannelPositions",
                             "ChannelLayout", "BitRate_Mode", "Compression_Mode"]
            for param in debugParams {
                if let value = getString(handle: handle, streamKind: .audio, streamNumber: 0, parameter: param) {
                    print("    - \(param): \(value)")
                }
            }
        }
        
        // Get audio bit rate in kbps
        let audioBitRateString = hasAudio ? getString(handle: handle, streamKind: .audio, streamNumber: 0, parameter: "BitRate") : nil
        let audioBitRate: Int? = if let bitRateStr = audioBitRateString {
            // MediaInfo returns bit rate in bps, convert to kbps
            (Int(bitRateStr) ?? 0) / 1000
        } else {
            nil
        }
        
        return MediaFileInfo(
            formatName: formatName ?? "unknown",
            hasVideo: hasVideo,
            hasAudio: hasAudio,
            videoCodec: videoCodec,
            audioCodec: audioCodec,
            duration: duration,
            audioBitDepth: audioBitDepth,
            audioSampleRate: audioSampleRate,
            audioChannels: audioChannels,
            audioBitRate: audioBitRate
        )
    }
    
    private func getString(handle: MediaInfoHandle, streamKind: StreamKind, streamNumber: Int, parameter: String) -> String? {
        parameter.withCString { param in
            if let result = mediaInfo_Get(handle, streamKind.rawValue, streamNumber, param, InfoKind.text.rawValue, InfoKind.name.rawValue) {
                let string = String(cString: result)
                return string.isEmpty ? nil : string
            }
            return nil
        }
    }
    
    private func getInt(handle: MediaInfoHandle, streamKind: StreamKind, streamNumber: Int, parameter: String) -> Int? {
        getString(handle: handle, streamKind: streamKind, streamNumber: streamNumber, parameter: parameter).flatMap { Int($0) }
    }
    
    private func getDouble(handle: MediaInfoHandle, streamKind: StreamKind, streamNumber: Int, parameter: String) -> Double? {
        getString(handle: handle, streamKind: streamKind, streamNumber: streamNumber, parameter: parameter).flatMap { Double($0) }
    }
}

enum MediaInfoError: LocalizedError {
    case libraryNotFound
    case loadFailed(String)
    case symbolNotFound(String)
    case initializationFailed
    case openFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .libraryNotFound:
            return "MediaInfoLib library not found in bundle"
        case .loadFailed(let error):
            return "Failed to load MediaInfoLib: \(error)"
        case .symbolNotFound(let symbol):
            return "Failed to find symbol \(symbol) in MediaInfoLib"
        case .initializationFailed:
            return "Failed to initialize MediaInfo instance"
        case .openFailed(let path):
            return "Failed to open file: \(path)"
        }
    }
}