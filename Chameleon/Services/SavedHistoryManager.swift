//
//  SavedHistoryManager.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import Foundation
import AppKit
import SwiftData

@MainActor
class SavedHistoryManager: ObservableObject {
    @Published var savedHistory: [ConversionRecord] = []
    
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadSavedHistory()
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
        
        modelContext.insert(record)
        try? modelContext.save()
        loadSavedHistory()
    }
    
    func removeConversion(_ record: ConversionRecord) {
        modelContext.delete(record)
        try? modelContext.save()
        loadSavedHistory()
    }
    
    func clearSavedHistory() {
        let fetchRequest = FetchDescriptor<ConversionRecord>()
        if let records = try? modelContext.fetch(fetchRequest) {
            for record in records {
                modelContext.delete(record)
            }
        }
        try? modelContext.save()
        loadSavedHistory()
    }
    
    func openFile(_ record: ConversionRecord) {
        guard record.isFileAccessible else { return }
        NSWorkspace.shared.open(record.outputFileURL)
    }
    
    func revealInFinder(_ record: ConversionRecord) {
        guard record.isFileAccessible else { return }
        NSWorkspace.shared.selectFile(record.outputFileURL.path, inFileViewerRootedAtPath: "")
    }
    
    private func loadSavedHistory() {
        let fetchDescriptor = FetchDescriptor<ConversionRecord>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        if let records = try? modelContext.fetch(fetchDescriptor) {
            savedHistory = records
        } else {
            savedHistory = []
        }
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