//
//  FileState.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import Foundation

enum FileState: Identifiable {
    case input(URL)
    case converting(URL, fileName: String)
    case converted(ConvertedFile)
    case error(URL, errorMessage: String)
    
    var id: String {
        switch self {
        case .input(let url), .converting(let url, _), .error(let url, _):
            return url.absoluteString
        case .converted(let file):
            return file.id.uuidString
        }
    }
    
    var fileName: String {
        switch self {
        case .input(let url), .error(let url, _):
            return url.lastPathComponent
        case .converting(_, let fileName):
            return fileName
        case .converted(let file):
            return file.fileName
        }
    }
    
    var url: URL? {
        switch self {
        case .input(let url), .converting(let url, _), .error(let url, _):
            return url
        case .converted(let file):
            return file.originalURL
        }
    }
    
    var isConverting: Bool {
        switch self {
        case .converting:
            return true
        default:
            return false
        }
    }
}