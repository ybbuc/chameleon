//
//  ConvertedFile.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//

import UniformTypeIdentifiers

struct ConvertedFile: Identifiable {
    let id = UUID()
    let originalURL: URL
    let tempURL: URL
    let fileName: String
    /// Additional original URLs for merged files (e.g., when merging PDFs)
    let additionalOriginalURLs: [URL]
    
    /// All original URLs including the primary and additional ones
    var allOriginalURLs: [URL] {
        [originalURL] + additionalOriginalURLs
    }
    
    /// Convenience initializer for single file conversions
    init(originalURL: URL, tempURL: URL, fileName: String) {
        self.originalURL = originalURL
        self.tempURL = tempURL
        self.fileName = fileName
        self.additionalOriginalURLs = []
    }
    
    /// Initializer for merged file conversions
    init(originalURLs: [URL], tempURL: URL, fileName: String) {
        self.originalURL = originalURLs.first ?? URL(fileURLWithPath: "")
        self.tempURL = tempURL
        self.fileName = fileName
        self.additionalOriginalURLs = Array(originalURLs.dropFirst())
    }

    /// Reads the data from the temporary file
    var data: Data? {
        try? Data(contentsOf: tempURL)
    }
}
