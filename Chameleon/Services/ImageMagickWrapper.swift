//
//  ImageMagickWrapper.swift
//  Chameleon
//
//  Created by Jakob Wells on 22.06.25.
//

import Foundation
import Darwin

class ImageMagickWrapper {
    private let magickPath: String
    private var currentProcess: Process?

    init() throws {
        // Use only bundled magick binary
        guard let bundlePath = Bundle.main.path(forResource: "magick", ofType: nil) else {
            throw ImageMagickError.imageMagickNotInstalled
        }
        
        guard FileManager.default.fileExists(atPath: bundlePath) && FileManager.default.isExecutableFile(atPath: bundlePath) else {
            throw ImageMagickError.imageMagickNotInstalled
        }
        
        // Libraries should be in Contents/libs/ directory (build-time setup required)
        
        print("Using bundled ImageMagick at: \(bundlePath)")
        self.magickPath = bundlePath
    }

    func convertImage(inputURL: URL, outputURL: URL, to outputFormat: ImageFormat, quality: Int = 100, dpi: Int = 150) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: magickPath)

        var arguments: [String] = []

        // Special handling for PDF input files
        if inputURL.pathExtension.lowercased() == "pdf" {
            // Set density for better quality and convert all pages
            arguments.append(contentsOf: ["-density", "\(dpi)"])
            arguments.append(inputURL.path) // No [0] means all pages
        } else {
            arguments.append(inputURL.path)
        }

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
        case .bmp:
            // Ensure BMP3 format for better compatibility with macOS
            arguments.append(contentsOf: ["-define", "bmp:format=bmp3"])
        default:
            break
        }

        arguments.append(outputURL.path)
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        // Set up environment to use bundled libraries
        var environment = ProcessInfo.processInfo.environment
        
        // Point to bundled libs directory - magick expects libs at @executable_path/../libs/
        let bundleContentsPath = Bundle.main.bundlePath
        let libsPath = bundleContentsPath + "/Contents/Resources"
        environment["DYLD_LIBRARY_PATH"] = libsPath
        environment["LD_LIBRARY_PATH"] = libsPath
        
        // Also set the path where magick binary expects to find libs
        let expectedLibsPath = bundleContentsPath + "/Contents/libs"
        environment["DYLD_FALLBACK_LIBRARY_PATH"] = "\(libsPath):\(expectedLibsPath)"
        
        process.environment = environment

        try process.run()

        // Wait for completion with cancellation support
        currentProcess = process
        defer { currentProcess = nil }

        while process.isRunning {
            if Task.isCancelled {
                // Send SIGINT to ImageMagick for graceful shutdown
                let processID = process.processIdentifier
                if processID > 0 {
                    kill(processID, SIGINT)
                }

                // Give ImageMagick a moment to clean up
                for _ in 0..<10 { // Wait up to 1 second
                    if !process.isRunning {
                        break
                    }
                    try await Task.sleep(for: .milliseconds(100))
                }

                // Force terminate if still running
                if process.isRunning {
                    process.terminate()
                }

                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"

            // Check for common dependency errors
            if errorString.contains("potrace") {
                throw ImageMagickError.potraceNotInstalled
            }

            throw ImageMagickError.conversionFailed(errorString)
        }
    }

    func cancel() {
        if let process = currentProcess {
            // ImageMagick handles SIGINT gracefully and will clean up properly
            let processID = process.processIdentifier
            if processID > 0 {
                // Send SIGINT (Ctrl+C) which ImageMagick handles gracefully
                kill(processID, SIGINT)
            }
            currentProcess = nil
        }
    }
}

enum ImageFormat: String, CaseIterable {
    case jpeg
    case jpg
    case png
    case gif
    case bmp
    case tiff
    case tif
    case webp
    case pdf
    case svg
    case ico

    var config: ImageFormatConfig {
        switch self {
        case .jpeg, .jpg:
            return JPEGConfig()
        case .png:
            return PNGConfig()
        case .gif:
            return GIFConfig()
        case .bmp:
            return BMPConfig()
        case .tiff, .tif:
            return TIFFConfig()
        case .webp:
            return WebPConfig()
        case .pdf:
            return PDFConfig()
        case .svg:
            return SVGConfig()
        case .ico:
            return ICOConfig()
        }
    }

    var isLossy: Bool { config.isLossy }
    var supportsExifMetadata: Bool { config.supportsExifMetadata }
    var requiresDpiConfiguration: Bool { config.requiresDpiConfiguration }
    var compressionSupported: Bool { config.compressionSupported }
    var transparencySupported: Bool { config.transparencySupported }
    var animationSupported: Bool { config.animationSupported }

    var displayName: String {
        return config.displayName
    }

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .tiff: return "tif"
        default: return rawValue
        }
    }

    var description: String? { config.description }

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
        .jpeg, .png, .gif, .bmp, .tiff, .webp, .pdf, .svg, .ico
    ]
}

enum ImageMagickError: LocalizedError {
    case imageMagickNotInstalled
    case ghostscriptNotInstalled
    case potraceNotInstalled
    case conversionFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageMagickNotInstalled:
            return "ImageMagick is not installed. Please install it via Homebrew: brew install imagemagick"
        case .ghostscriptNotInstalled:
            return "Ghostscript is required for PDF conversion. Please install it via Homebrew: brew install ghostscript"
        case .potraceNotInstalled:
            return "Potrace is required for SVG conversion. Please install it via Homebrew: brew install potrace"
        case .conversionFailed(let message):
            if message.contains("gs: command not found") {
                return "Ghostscript is required for PDF conversion. Please install it via Homebrew: brew install ghostscript"
            }
            return "ImageMagick conversion failed: \(message)"
        }
    }
}
