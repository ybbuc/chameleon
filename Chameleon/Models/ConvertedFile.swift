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

    /// Reads the data from the temporary file
    var data: Data? {
        try? Data(contentsOf: tempURL)
    }
}
