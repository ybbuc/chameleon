//
//  ImageFormatConfig.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import Foundation

// MARK: - Image Format Configuration Protocol

protocol ImageFormatConfig {
    var displayName: String { get }
    var description: String? { get }
    var fileExtension: String { get }
    var isLossy: Bool { get }
    var supportsExifMetadata: Bool { get }
    var requiresDpiConfiguration: Bool { get }
    var compressionSupported: Bool { get }
    var transparencySupported: Bool { get }
    var animationSupported: Bool { get }
}

// MARK: - Image Format Configurations

struct JPEGConfig: ImageFormatConfig {
    let displayName = "JPEG"
    let description: String? = "Widely supported lossy format with good compression. " +
                               "Ideal for photos and images with many colors."
    let fileExtension = "jpg"
    let isLossy = true
    let supportsExifMetadata = true
    let requiresDpiConfiguration = false
    let compressionSupported = true
    let transparencySupported = false
    let animationSupported = false
}

struct PNGConfig: ImageFormatConfig {
    let displayName = "PNG"
    let description: String? = "Lossless format ideal for images with sharp edges, text, or transparent backgrounds."
    let fileExtension = "png"
    let isLossy = false
    let supportsExifMetadata = false
    let requiresDpiConfiguration = false
    let compressionSupported = true
    let transparencySupported = true
    let animationSupported = false
}

struct GIFConfig: ImageFormatConfig {
    let displayName = "GIF"
    let description: String? = "Supports 256 colors with animation and transparency, " +
                               "ideal for simple graphics and animations."
    let fileExtension = "gif"
    let isLossy = false
    let supportsExifMetadata = false
    let requiresDpiConfiguration = false
    let compressionSupported = true
    let transparencySupported = true
    let animationSupported = true
}

struct BMPConfig: ImageFormatConfig {
    let displayName = "BMP"
    let description: String? = "Uncompressed format with large file sizes. " +
                               "Widely supported but inefficient for storage."
    let fileExtension = "bmp"
    let isLossy = false
    let supportsExifMetadata = false
    let requiresDpiConfiguration = false
    let compressionSupported = false
    let transparencySupported = false
    let animationSupported = false
}

struct TIFFConfig: ImageFormatConfig {
    let displayName = "TIFF"
    let description: String? = "Lossless with extensive metadata capabilities, " +
                               "widely used in publishing and photography."
    let fileExtension = "tif"
    let isLossy = false
    let supportsExifMetadata = true
    let requiresDpiConfiguration = false
    let compressionSupported = true
    let transparencySupported = true
    let animationSupported = false
}

struct WebPConfig: ImageFormatConfig {
    let displayName = "WebP"
    let description: String? = "Modern format with excellent compression, supporting both lossy and lossless modes."
    let fileExtension = "webp"
    let isLossy = true
    let supportsExifMetadata = false
    let requiresDpiConfiguration = false
    let compressionSupported = true
    let transparencySupported = true
    let animationSupported = true
}

struct PDFConfig: ImageFormatConfig {
    let displayName = "PDF (Image)"
    let description: String? = "Document format that can contain images and vector graphics."
    let fileExtension = "pdf"
    let isLossy = false
    let supportsExifMetadata = false
    let requiresDpiConfiguration = true
    let compressionSupported = true
    let transparencySupported = false
    let animationSupported = false
}

struct SVGConfig: ImageFormatConfig {
    let displayName = "SVG"
    let description: String? = "Scalable vector format ideal for logos and simple graphics. " +
                               "Maintains quality at any size."
    let fileExtension = "svg"
    let isLossy = false
    let supportsExifMetadata = false
    let requiresDpiConfiguration = false
    let compressionSupported = false
    let transparencySupported = true
    let animationSupported = false
}

struct ICOConfig: ImageFormatConfig {
    let displayName = "ICO"
    let description: String? = "Windows icon format supporting multiple sizes and transparency. " +
                               "Used for application icons."
    let fileExtension = "ico"
    let isLossy = false
    let supportsExifMetadata = false
    let requiresDpiConfiguration = false
    let compressionSupported = false
    let transparencySupported = true
    let animationSupported = false
}
