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
    let data: Data
    let fileName: String
}
