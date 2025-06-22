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

class ConversionHistoryManager: ObservableObject {
    @Published var recentConversions: [ConversionRecord] = []
    
    private let maxHistoryCount = 50
    private let userDefaults = UserDefaults.standard
    private let historyKey = "ConversionHistory"
    
    init() {
        loadHistory()
    }
    
    func addConversion(
        inputFileName: String,
        inputFormat: String,
        outputFormat: String,
        outputFileURL: URL
    ) {
        let outputFileName = outputFileURL.lastPathComponent
        let fileSize = getFileSize(at: outputFileURL)
        
        let record = ConversionRecord(
            inputFileName: inputFileName,
            inputFormat: inputFormat,
            outputFormat: outputFormat,
            outputFileName: outputFileName,
            outputFileURL: outputFileURL,
            timestamp: Date(),
            fileSize: fileSize
        )
        
        // Add to beginning of array
        recentConversions.insert(record, at: 0)
        
        // Keep only the most recent conversions
        if recentConversions.count > maxHistoryCount {
            recentConversions = Array(recentConversions.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    func removeConversion(_ record: ConversionRecord) {
        recentConversions.removeAll { $0.id == record.id }
        saveHistory()
    }
    
    func clearHistory() {
        recentConversions.removeAll()
        saveHistory()
    }
    
    func openFile(_ record: ConversionRecord) {
        guard record.isFileAccessible else { return }
        NSWorkspace.shared.open(record.outputFileURL)
    }
    
    func revealInFinder(_ record: ConversionRecord) {
        guard record.isFileAccessible else { return }
        NSWorkspace.shared.selectFile(record.outputFileURL.path, inFileViewerRootedAtPath: "")
    }
    
    private func loadHistory() {
        guard let data = userDefaults.data(forKey: historyKey),
              let decoded = try? JSONDecoder().decode([ConversionRecord].self, from: data) else {
            return
        }
        recentConversions = decoded
    }
    
    private func saveHistory() {
        guard let encoded = try? JSONEncoder().encode(recentConversions) else { return }
        userDefaults.set(encoded, forKey: historyKey)
    }
    
    private func getFileSize(at url: URL) -> Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
}