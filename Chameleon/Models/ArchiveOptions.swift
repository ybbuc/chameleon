//
//  ArchiveOptions.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import Foundation

struct ArchiveOptions {
    var archiveSeparately: Bool = false
    var verifyAfterCreation: Bool = true
    var compressionLevel: CompressionLevel = .normal
}
