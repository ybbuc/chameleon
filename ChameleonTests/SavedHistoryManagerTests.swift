//
//  SavedHistoryManagerTests.swift
//  ChameleonTests
//
//  Created by Jakob Wells on 03.07.25.
//

import Testing
import Foundation
import SwiftData
@testable import Chameleon

@MainActor
struct SavedHistoryManagerTests {

    // Create an in-memory ModelContainer for testing
    private func createTestContainer() throws -> ModelContainer {
        let schema = Schema([ConversionRecord.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    }

    @Test
    func testSavedHistoryManagerInit() async throws {
        let container = try createTestContainer()
        let manager = SavedHistoryManager(modelContext: container.mainContext)

        #expect(manager.savedHistory.isEmpty)
        #expect(manager.hasMissingFiles == false)
    }

    @Test
    func testAddConversion() async throws {
        let container = try createTestContainer()
        let manager = SavedHistoryManager(modelContext: container.mainContext)

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.pdf")

        // Create a temporary file for testing
        try "Test content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        manager.addConversion(
            inputFileName: "test.md",
            inputFormat: "markdown",
            outputFormat: "pdf",
            outputFileURL: tempURL
        )

        #expect(manager.savedHistory.count == 1)

        guard let record = manager.savedHistory.first else {
            #expect(Bool(false), "Should have a saved record")
            return
        }
        #expect(record.inputFileName == "test.md")
        #expect(record.inputFormat == "markdown")
        #expect(record.outputFormat == "pdf")
        #expect(record.outputFileName == "test.pdf")
        #expect(record.isFileAccessible == true)
    }

    @Test
    func testRemoveConversion() async throws {
        let container = try createTestContainer()
        let manager = SavedHistoryManager(modelContext: container.mainContext)

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.pdf")
        try "Test content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        manager.addConversion(
            inputFileName: "test.md",
            inputFormat: "markdown",
            outputFormat: "pdf",
            outputFileURL: tempURL
        )

        #expect(manager.savedHistory.count == 1)

        guard let record = manager.savedHistory.first else {
            #expect(Bool(false), "Should have a saved record")
            return
        }
        manager.removeConversion(record)

        #expect(manager.savedHistory.isEmpty)
    }

    @Test
    func testClearSavedHistory() async throws {
        let container = try createTestContainer()
        let manager = SavedHistoryManager(modelContext: container.mainContext)

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.pdf")
        try "Test content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // Add multiple conversions
        manager.addConversion(
            inputFileName: "test1.md",
            inputFormat: "markdown",
            outputFormat: "pdf",
            outputFileURL: tempURL
        )

        manager.addConversion(
            inputFileName: "test2.md",
            inputFormat: "markdown",
            outputFormat: "html",
            outputFileURL: tempURL
        )

        #expect(manager.savedHistory.count == 2)

        manager.clearSavedHistory()
        #expect(manager.savedHistory.isEmpty)
    }

    @Test
    func testMissingFilesHandling() async throws {
        let container = try createTestContainer()
        let manager = SavedHistoryManager(modelContext: container.mainContext)

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_missing.pdf")

        // Create and then delete the file
        try "Test content".write(to: tempURL, atomically: true, encoding: .utf8)

        manager.addConversion(
            inputFileName: "test.md",
            inputFormat: "markdown",
            outputFormat: "pdf",
            outputFileURL: tempURL
        )

        // Delete the file to simulate a missing file
        try FileManager.default.removeItem(at: tempURL)

        manager.checkForMissingFiles()
        #expect(manager.hasMissingFiles == true)

        // Test clearing missing files
        manager.clearMissingFiles()
        #expect(manager.savedHistory.isEmpty)
        #expect(manager.hasMissingFiles == false)
    }

    @Test
    func testConversionRecordProperties() async throws {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.pdf")
        try "Test content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let timestamp = Date()
        let record = ConversionRecord(
            inputFileName: "test.md",
            inputFormat: "markdown",
            outputFormat: "pdf",
            outputFileName: "test.pdf",
            outputFileURL: tempURL,
            timestamp: timestamp,
            fileSize: 12
        )

        #expect(record.inputFileName == "test.md")
        #expect(record.isFileAccessible == true)
        #expect(record.formattedFileSize == "12 bytes")
        #expect(!record.formattedDate.isEmpty)
        #expect(record.relativeTime == "Just now")
        #expect(record.thumbnailImage == nil) // No thumbnail data set
    }

    @Test
    func testFileAccessibility() async throws {
        let container = try createTestContainer()
        let manager = SavedHistoryManager(modelContext: container.mainContext)

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_access.pdf")
        try "Test content".write(to: tempURL, atomically: true, encoding: .utf8)

        manager.addConversion(
            inputFileName: "test.md",
            inputFormat: "markdown",
            outputFormat: "pdf",
            outputFileURL: tempURL
        )

        guard let record = manager.savedHistory.first else {
            #expect(Bool(false), "Should have a saved record")
            return
        }
        #expect(record.isFileAccessible == true)

        // Delete the file
        try FileManager.default.removeItem(at: tempURL)
        #expect(record.isFileAccessible == false)
    }

    @Test
    func testOpenFile() async throws {
        let container = try createTestContainer()
        let manager = SavedHistoryManager(modelContext: container.mainContext)

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_open.txt")
        try "Test content for opening".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        manager.addConversion(
            inputFileName: "test.md",
            inputFormat: "markdown",
            outputFormat: "txt",
            outputFileURL: tempURL
        )

        guard let record = manager.savedHistory.first else {
            #expect(Bool(false), "Should have a saved record")
            return
        }

        // We can't actually test NSWorkspace.open in unit tests,
        // but we can verify the method doesn't crash
        manager.openFile(record)

        // Test that it doesn't try to open missing files
        try FileManager.default.removeItem(at: tempURL)
        manager.openFile(record) // Should not crash
    }

    @Test
    func testRevealInFinder() async throws {
        let container = try createTestContainer()
        let manager = SavedHistoryManager(modelContext: container.mainContext)

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test_reveal.txt")
        try "Test content for reveal".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        manager.addConversion(
            inputFileName: "test.md",
            inputFormat: "markdown",
            outputFormat: "txt",
            outputFileURL: tempURL
        )

        guard let record = manager.savedHistory.first else {
            #expect(Bool(false), "Should have a saved record")
            return
        }

        // We can't actually test NSWorkspace.activateFileViewerSelecting in unit tests,
        // but we can verify the method doesn't crash
        manager.revealInFinder(record)

        // Test that it doesn't try to reveal missing files
        try FileManager.default.removeItem(at: tempURL)
        manager.revealInFinder(record) // Should not crash
    }
}
