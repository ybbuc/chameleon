//
//  OCRFormatConfig.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import Foundation

// MARK: - OCR Format Configuration Protocol

protocol OCRFormatConfig {
    var displayName: String { get }
    var description: String? { get }
    var fileExtension: String { get }
    var preservesFormatting: Bool { get }
    var includesMetadata: Bool { get }
}

// MARK: - OCR Format Configurations

struct TXTConfig: OCRFormatConfig {
    let displayName = "Plain Text"
    let description: String? = "Simple text extraction without formatting"
    let fileExtension = "txt"
    let preservesFormatting = false
    let includesMetadata = false
}

// MARK: - Format Registry Extension

extension FormatRegistry {
    func config(for format: OCRFormat) -> OCRFormatConfig? {
        switch format {
        case .txt, .txtExtract, .txtOCR:
            return TXTConfig()
        }
    }
}
