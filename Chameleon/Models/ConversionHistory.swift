//
//  ConversionHistory.swift
//  Chameleon
//
//  Created by Jakob Wells on 22.06.25.
//

import Foundation
import AppKit

struct ConversionRecord: Codable, Identifiable {
    let id: UUID
    let inputFileName: String
    let inputFormat: String
    let outputFormat: String
    let outputFileName: String
    let outputFileURL: URL
    let timestamp: Date
    let fileSize: Int64
    
    init(inputFileName: String, inputFormat: String, outputFormat: String, outputFileName: String, outputFileURL: URL, timestamp: Date, fileSize: Int64) {
        self.id = UUID()
        self.inputFileName = inputFileName
        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        self.outputFileName = outputFileName
        self.outputFileURL = outputFileURL
        self.timestamp = timestamp
        self.fileSize = fileSize
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    var isFileAccessible: Bool {
        FileManager.default.fileExists(atPath: outputFileURL.path)
    }
}


