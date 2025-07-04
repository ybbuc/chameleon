//
//  MediaInfoWrapper.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//
//  Wrapper for MediaInfoLib library to get media file information
//

import Foundation
import UniformTypeIdentifiers

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
        
        // Check for subtitle/text streams
        let textStreamCount = getInt(handle: handle, streamKind: .text, streamNumber: 0, parameter: "StreamCount") ?? 0
        let hasSubtitles = textStreamCount > 0
        print("  💬 Subtitle streams: \(textStreamCount)")
        
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
            let debugParams = ["Format", "Format/String", "Format_Commercial", "Format_Commercial_IfAny",
                             "Format_Version", "Format_Profile", "Format_Settings", "Format_Info",
                             "CodecID", "CodecID/String", "CodecID/Info", "CodecID/Hint",
                             "BitRate", "SamplingRate", "BitDepth", 
                             "Resolution", "BitDepth_Detected", "Channels", "ChannelPositions",
                             "ChannelLayout", "BitRate_Mode", "Compression_Mode", "StreamKind",
                             "StreamKind/String", "StreamCount"]
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
            hasSubtitles: hasSubtitles,
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

extension MediaInfoWrapper {
    func getDetailedFileInfo(url: URL) throws -> DetailedMediaInfo {
        // Create MediaInfo instance
        guard let handle = mediaInfo_New() else {
            throw MediaInfoError.initializationFailed
        }
        
        defer {
            mediaInfo_Delete(handle)
        }
        
        // Open the file
        let result = url.path.withCString { path in
            mediaInfo_Open(handle, path)
        }
        
        guard result > 0 else {
            throw MediaInfoError.openFailed(url.path)
        }
        
        defer {
            mediaInfo_Close(handle)
        }
        
        // Get file size and dates
        let fileSize = FileManager.default.fileSize(at: url) ?? 0
        let fileDates = FileManager.default.fileDates(at: url)
        
        // Get general info
        var format = getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "Format")
        
        // If MediaInfo doesn't recognize the format, get it from the system
        if format == nil || format?.isEmpty == true {
            // Use UTType to get the system's description of the file type
            if let utType = UTType(filenameExtension: url.pathExtension) {
                format = utType.localizedDescription ?? utType.preferredFilenameExtension
            }
        }
        
        let finalFormat = format ?? "Unknown"
        let overallBitRateString = getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "OverallBitRate")
        let overallBitRate = overallBitRateString.flatMap { Int($0) }.map { $0 / 1000 }
        let overallBitRateMode = getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "OverallBitRate_Mode")
        
        // Get duration in seconds
        let durationMs = getDouble(handle: handle, streamKind: .general, streamNumber: 0, parameter: "Duration")
        let duration = durationMs.map { $0 / 1000.0 }
        
        // Get encoding application and writing library
        let encodingApplication = getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "Encoded_Application")
            ?? getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "Writing_Application")
        let writingLibrary = getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "Encoded_Library")
            ?? getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "Writing_Library")
        
        // Get video stream count
        let videoStreamCountStr = getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "VideoCount")
        let videoStreamCount = videoStreamCountStr.flatMap { Int($0) } ?? 0
        
        // Get all video streams
        var videoStreams: [VideoStreamInfo] = []
        for streamIndex in 0..<videoStreamCount {
            // Check if stream exists by trying to get codec
            if let codec = getString(handle: handle, streamKind: .video, streamNumber: streamIndex, parameter: "Format") {
                let width = getInt(handle: handle, streamKind: .video, streamNumber: streamIndex, parameter: "Width")
                let height = getInt(handle: handle, streamKind: .video, streamNumber: streamIndex, parameter: "Height")
                let resolution = (width != nil && height != nil) ? "\(width!)×\(height!)" : nil
                let frameRate = getDouble(handle: handle, streamKind: .video, streamNumber: streamIndex, parameter: "FrameRate")
                let bitRateString = getString(handle: handle, streamKind: .video, streamNumber: streamIndex, parameter: "BitRate")
                let bitRate = bitRateString.flatMap { Int($0) }.map { $0 / 1000 }
                let colorSpace = getString(handle: handle, streamKind: .video, streamNumber: streamIndex, parameter: "ColorSpace")
                let pixelFormat = getString(handle: handle, streamKind: .video, streamNumber: streamIndex, parameter: "PixelFormat")
                let aspectRatio = getString(handle: handle, streamKind: .video, streamNumber: streamIndex, parameter: "DisplayAspectRatio/String")
                
                let streamInfo = VideoStreamInfo(
                    streamIndex: streamIndex,
                    codec: codec,
                    resolution: resolution,
                    frameRate: frameRate,
                    bitRate: bitRate,
                    colorSpace: colorSpace,
                    pixelFormat: pixelFormat,
                    aspectRatio: aspectRatio
                )
                videoStreams.append(streamInfo)
            }
        }
        
        // Get audio stream count
        let audioStreamCountStr = getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "AudioCount")
        let audioStreamCount = audioStreamCountStr.flatMap { Int($0) } ?? 0
        
        // Get all audio streams
        var audioStreams: [AudioStreamInfo] = []
        for streamIndex in 0..<audioStreamCount {
            // Check if stream exists by trying to get codec
            if let codec = getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Format") {
                // Check for commercial/expanded format names first
                let commercialFormat = getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Format_Commercial")
                    ?? getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Format_Commercial_IfAny")
                    ?? getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Format/String")
                
                // Use commercial format if available, otherwise handle special cases
                var finalCodec = commercialFormat ?? codec
                
                // Special handling for E-AC-3 if commercial format doesn't already indicate JOC
                if codec == "E-AC-3" && !finalCodec.contains("JOC") {
                    // Check Format_Settings_JOC or Format_AdditionalFeatures for JOC
                    let jocSetting = getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Format_Settings_JOC")
                    let additionalFeatures = getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Format_AdditionalFeatures")
                    let formatProfile = getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Format_Profile")
                    
                    if jocSetting == "Yes" || additionalFeatures?.contains("JOC") == true || formatProfile?.contains("JOC") == true {
                        finalCodec = commercialFormat ?? "E-AC-3 JOC"
                    }
                }
                
                let channels = getInt(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Channels")
                let sampleRate = getInt(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "SamplingRate")
                let bitDepth = getInt(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "BitDepth")
                let bitRateString = getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "BitRate")
                let bitRate = bitRateString.flatMap { Int($0) }.map { $0 / 1000 }
                let compressionMode = getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Compression_Mode")
                let language = getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Language/String")
                let title = getString(handle: handle, streamKind: .audio, streamNumber: streamIndex, parameter: "Title")
                
                // Debug output for commercial formats
                if streamIndex == 0 {
                    print("  🔍 Debug - Audio stream \(streamIndex) format details:")
                    print("    - Base Format: \(codec)")
                    print("    - Commercial Format: \(commercialFormat ?? "nil")")
                    print("    - Final Codec: \(finalCodec)")
                }
                
                let streamInfo = AudioStreamInfo(
                    streamIndex: streamIndex,
                    codec: finalCodec,
                    channels: channels,
                    sampleRate: sampleRate,
                    bitDepth: bitDepth,
                    bitRate: bitRate,
                    compressionMode: compressionMode,
                    language: language,
                    title: title
                )
                audioStreams.append(streamInfo)
            }
        }
        
        // Get subtitle/text stream count
        let textStreamCountStr = getString(handle: handle, streamKind: .general, streamNumber: 0, parameter: "TextCount")
        let textStreamCount = textStreamCountStr.flatMap { Int($0) } ?? 0
        
        // Get all subtitle streams
        var subtitleStreams: [SubtitleStreamInfo] = []
        for streamIndex in 0..<textStreamCount {
            // Check if stream exists by trying to get format
            if let format = getString(handle: handle, streamKind: .text, streamNumber: streamIndex, parameter: "Format") {
                // For text-based subtitles, MediaInfo sometimes reports the encoding as the format
                let codecID = getString(handle: handle, streamKind: .text, streamNumber: streamIndex, parameter: "CodecID")
                let encoding = getString(handle: handle, streamKind: .text, streamNumber: streamIndex, parameter: "Encoding")
                
                // Map common codec IDs to friendly names
                let friendlyCodec: String? = switch codecID {
                    case "S_TEXT/UTF8": "SRT"
                    case "S_TEXT/ASS": "ASS"
                    case "S_TEXT/SSA": "SSA"
                    case "S_TEXT/WEBVTT": "WebVTT"
                    case "S_HDMV/PGS": "PGS"
                    case "S_VOBSUB": "VobSub"
                    default: nil
                }
                
                // Determine the actual codec
                let codec = if ["UTF-8", "UTF-16", "UTF-16BE", "UTF-16LE", "ISO-8859-1", "ASCII"].contains(format) {
                    friendlyCodec ?? "Text"
                } else {
                    format
                }
                
                let language = getString(handle: handle, streamKind: .text, streamNumber: streamIndex, parameter: "Language/String")
                let title = getString(handle: handle, streamKind: .text, streamNumber: streamIndex, parameter: "Title")
                let forced = getString(handle: handle, streamKind: .text, streamNumber: streamIndex, parameter: "Forced") == "Yes"
                let isDefault = getString(handle: handle, streamKind: .text, streamNumber: streamIndex, parameter: "Default") == "Yes"
                
                // Determine encoding - if format was an encoding, use it; otherwise use the Encoding parameter
                let actualEncoding = if ["UTF-8", "UTF-16", "UTF-16BE", "UTF-16LE", "ISO-8859-1", "ASCII"].contains(format) {
                    format
                } else {
                    encoding
                }
                
                // Debug logging
                print("🔍 Subtitle Stream \(streamIndex):")
                print("   Format: \(format)")
                print("   CodecID: \(codecID ?? "nil")")
                print("   Encoding param: \(encoding ?? "nil")")
                print("   Final codec: \(codec)")
                print("   Final encoding: \(actualEncoding ?? "nil")")
                
                let streamInfo = SubtitleStreamInfo(
                    streamIndex: streamIndex,
                    codec: codec,
                    encoding: actualEncoding,
                    language: language,
                    title: title,
                    forced: forced,
                    `default`: isDefault
                )
                subtitleStreams.append(streamInfo)
            }
        }
        
        let detailedInfo = DetailedMediaInfo(
            format: finalFormat,
            fileSize: fileSize,
            createdDate: fileDates?.created,
            modifiedDate: fileDates?.modified,
            duration: duration,
            overallBitRate: overallBitRate,
            overallBitRateMode: overallBitRateMode,
            encodingApplication: encodingApplication,
            writingLibrary: writingLibrary,
            videoStreams: videoStreams,
            audioStreams: audioStreams,
            subtitleStreams: subtitleStreams
        )
        
        return detailedInfo
    }
}

extension FileManager {
    func fileSize(at url: URL) -> Int64? {
        do {
            let attributes = try attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    func fileDates(at url: URL) -> (created: Date?, modified: Date?)? {
        do {
            let attributes = try attributesOfItem(atPath: url.path)
            let created = attributes[.creationDate] as? Date
            let modified = attributes[.modificationDate] as? Date
            return (created, modified)
        } catch {
            return nil
        }
    }
}