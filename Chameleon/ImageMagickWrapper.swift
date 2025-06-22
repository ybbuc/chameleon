//
//  ImageMagickWrapper.swift
//  Chameleon
//
//  Created by Jakob Wells on 22.06.25.
//

import Foundation

class ImageMagickWrapper {
    private let magickPath: String
    
    init() throws {
        // Use system convert from PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["convert"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                print("Found ImageMagick convert at: \(path)")
                self.magickPath = path
                return
            }
        }
        
        // Fallback to common locations
        let commonPaths = [
            "/usr/local/bin/convert",
            "/opt/homebrew/bin/convert",
            "/opt/local/bin/convert"
        ]
        
        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path) {
                print("Found ImageMagick convert at fallback location: \(path)")
                self.magickPath = path
                return
            }
        }
        
        throw ImageMagickError.imageMagickNotInstalled
    }
    
    func convertImage(inputURL: URL, outputURL: URL, to outputFormat: ImageFormat, quality: Int = 85) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: magickPath)
        
        var arguments = [inputURL.path]
        
        // Add quality setting for lossy formats
        if outputFormat.isLossy {
            arguments.append(contentsOf: ["-quality", "\(quality)"])
        }
        
        // Add format-specific options
        switch outputFormat {
        case .png:
            arguments.append(contentsOf: ["-define", "png:compression-level=9"])
        case .webp:
            arguments.append(contentsOf: ["-define", "webp:lossless=false"])
        default:
            break
        }
        
        arguments.append(outputURL.path)
        process.arguments = arguments
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ImageMagickError.conversionFailed(errorString)
        }
    }
}

enum ImageFormat: String, CaseIterable {
    case jpeg = "jpeg"
    case jpg = "jpg" 
    case png = "png"
    case gif = "gif"
    case bmp = "bmp"
    case tiff = "tiff"
    case tif = "tif"
    case webp = "webp"
    case heic = "heic"
    case heif = "heif"
    case pdf = "pdf"
    case svg = "svg"
    case ico = "ico"
    case raw = "raw"
    
    var isLossy: Bool {
        switch self {
        case .jpeg, .jpg, .webp, .heic, .heif:
            return true
        default:
            return false
        }
    }
    
    var displayName: String {
        switch self {
        case .jpeg, .jpg: return "JPEG"
        case .png: return "PNG"
        case .gif: return "GIF"
        case .bmp: return "BMP"
        case .tiff, .tif: return "TIFF"
        case .webp: return "WebP"
        case .heic: return "HEIC"
        case .heif: return "HEIF"
        case .pdf: return "PDF"
        case .svg: return "SVG"
        case .ico: return "ICO"
        case .raw: return "RAW"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .tiff: return "tif"
        default: return rawValue
        }
    }
    
    static func detectFormat(from url: URL) -> ImageFormat? {
        let ext = url.pathExtension.lowercased()
        return ImageFormat.allCases.first { format in
            format.rawValue == ext || format.fileExtension == ext
        }
    }
    
    // Input formats that ImageMagick can read
    static let inputFormats: Set<ImageFormat> = Set(ImageFormat.allCases)
    
    // Output formats that ImageMagick can write
    static let outputFormats: Set<ImageFormat> = [
        .jpeg, .jpg, .png, .gif, .bmp, .tiff, .tif, .webp, .pdf, .svg, .ico
    ]
}

enum ImageMagickError: LocalizedError {
    case imageMagickNotInstalled
    case conversionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .imageMagickNotInstalled:
            return "ImageMagick is not installed. Please install it via Homebrew: brew install imagemagick"
        case .conversionFailed(let message):
            return "ImageMagick conversion failed: \(message)"
        }
    }
}