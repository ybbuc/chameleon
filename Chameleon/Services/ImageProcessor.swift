//
//  ImageProcessor.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//

import Foundation
import ImageIO
import CoreGraphics

class ImageProcessor {
    
    static let shared = ImageProcessor()
    
    private init() {}
    
    func strip(exifMetadataExceptOrientation url: URL) throws {
        // Check if this is a supported image format for EXIF processing
        let supportedExtensions = ["jpg", "jpeg", "tiff", "tif", "heic", "heif"]
        let fileExtension = url.pathExtension.lowercased()
        
        guard supportedExtensions.contains(fileExtension) else {
            // Skip EXIF stripping for formats that don't support EXIF metadata
            return
        }
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ImageProcessorError.failedToReadImage
        }
        
        // Get image properties including EXIF data
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any]
        
        // Try to get orientation from multiple possible locations
        var orientation: Int = 1
        
        // First check the main properties
        if let mainOrientation = imageProperties?[kCGImagePropertyOrientation as String] as? Int {
            orientation = mainOrientation
        }
        // Then check EXIF dictionary
        else if let exifDict = imageProperties?[kCGImagePropertyExifDictionary as String] as? [String: Any],
                let exifOrientation = exifDict["Orientation"] as? Int {
            orientation = exifOrientation
        }
        // Also check TIFF dictionary (common for TIFF files)
        else if let tiffDict = imageProperties?[kCGImagePropertyTIFFDictionary as String] as? [String: Any],
                let tiffOrientation = tiffDict["Orientation"] as? Int {
            orientation = tiffOrientation
        }
        
        // Get the image format
        guard let uti = CGImageSourceGetType(imageSource) else {
            throw ImageProcessorError.failedToDetermineFormat
        }
        
        // Create destination with only orientation metadata preserved
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, uti, 1, nil) else {
            throw ImageProcessorError.failedToCreateDestination
        }
        
        // Create properties dictionary with orientation preserved in all relevant locations
        var preservedProperties: [String: Any] = [
            kCGImagePropertyOrientation as String: orientation
        ]
        
        // For JPEG/HEIF, also add orientation to EXIF dictionary
        if fileExtension == "jpg" || fileExtension == "jpeg" || fileExtension == "heic" || fileExtension == "heif" {
            preservedProperties[kCGImagePropertyExifDictionary as String] = [
                "Orientation": orientation
            ]
        }
        
        // For TIFF, add orientation to TIFF dictionary
        if fileExtension == "tiff" || fileExtension == "tif" {
            preservedProperties[kCGImagePropertyTIFFDictionary as String] = [
                "Orientation": orientation
            ]
        }
        
        // Add image with only orientation metadata
        CGImageDestinationAddImage(destination, cgImage, preservedProperties as CFDictionary)
        
        if !CGImageDestinationFinalize(destination) {
            throw ImageProcessorError.failedToFinalizeImage
        }
    }
}

enum ImageProcessorError: LocalizedError {
    case failedToReadImage
    case failedToDetermineFormat
    case failedToCreateDestination
    case failedToFinalizeImage
    
    var errorDescription: String? {
        switch self {
        case .failedToReadImage:
            return "Failed to read image for EXIF processing"
        case .failedToDetermineFormat:
            return "Failed to determine image format"
        case .failedToCreateDestination:
            return "Failed to create image destination"
        case .failedToFinalizeImage:
            return "Failed to finalize processed image"
        }
    }
}