//
//  ConversionService.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


enum ConversionService: Hashable {
    case pandoc(PandocFormat)
    case imagemagick(ImageFormat)
    case ffmpeg(FFmpegFormat)
    case ocr(OCRFormat)
    
    var fileExtension: String {
        switch self {
        case .pandoc(let format):
            return format.fileExtension
        case .imagemagick(let format):
            return format.fileExtension
        case .ffmpeg(let format):
            return format.rawValue
        case .ocr(let format):
            return format.fileExtension
        }
    }
}