//
//  ConversionService.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


enum ConversionService: Hashable {
    case pandoc(PandocFormat)
    case imagemagick(ImageFormat)
    
    var fileExtension: String {
        switch self {
        case .pandoc(let format):
            return format.fileExtension
        case .imagemagick(let format):
            return format.fileExtension
        }
    }
}