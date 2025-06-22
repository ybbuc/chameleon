//
//  ChameleonTests.swift
//  ChameleonTests
//
//  Created by Jakob Wells on 22.06.25.
//

import Testing
import Foundation
@testable import Chameleon

struct ChameleonTests {
    
    // MARK: - PandocWrapper Tests
    
    @Test func testPandocWrapperInit() async throws {
        // Test that PandocWrapper can be initialized without throwing
        let _ = try PandocWrapper()
        // If we get here without throwing, the test passes
    }
    
    @Test func testPandocFormatDetection() async throws {
        // Test format detection from file extensions
        let mdURL = URL(fileURLWithPath: "/path/to/file.md")
        #expect(PandocFormat.detectFormat(from: mdURL) == .markdown)
        
        let htmlURL = URL(fileURLWithPath: "/path/to/file.html")
        #expect(PandocFormat.detectFormat(from: htmlURL) == .html)
        
        let pdfURL = URL(fileURLWithPath: "/path/to/file.pdf")
        #expect(PandocFormat.detectFormat(from: pdfURL) == .pdf)
        
        let unknownURL = URL(fileURLWithPath: "/path/to/file.xyz")
        #expect(PandocFormat.detectFormat(from: unknownURL) == nil)
    }
    
    @Test func testPandocFormatCompatibility() async throws {
        // Test that compatible output formats are returned
        let markdownOutputs = PandocFormat.compatibleOutputFormats(for: .markdown)
        #expect(markdownOutputs.contains(.html))
        #expect(markdownOutputs.contains(.pdf))
        #expect(markdownOutputs.contains(.docx))
        
        let csvOutputs = PandocFormat.compatibleOutputFormats(for: .csv)
        #expect(csvOutputs.contains(.html))
        #expect(csvOutputs.contains(.markdown))
        // CSV shouldn't be able to convert to presentation formats
        #expect(!csvOutputs.contains(.beamer))
    }
    
    @Test func testPandocStringConversion() async throws {
        // Only run if pandoc is available
        guard let wrapper = try? PandocWrapper() else {
            throw TestSkipError.init("Pandoc not available")
        }
        
        let markdown = "# Hello World\n\nThis is a test."
        let html = try await wrapper.convert(input: markdown, from: .markdown, to: .html)
        
        #expect(html.contains("<h1"))
        #expect(html.contains("Hello World"))
        #expect(html.contains("<p>"))
        #expect(html.contains("This is a test."))
    }
    
    // MARK: - ImageMagickWrapper Tests
    
    @Test func testImageMagickWrapperInit() async throws {
        // Test that ImageMagickWrapper can be initialized without throwing
        let _ = try ImageMagickWrapper()
        // If we get here without throwing, the test passes
    }
    
    @Test func testImageFormatDetection() async throws {
        // Test format detection from file extensions
        let jpegURL = URL(fileURLWithPath: "/path/to/image.jpg")
        #expect(ImageFormat.detectFormat(from: jpegURL) == .jpeg) // .jpg files detect as .jpeg (first match)
        
        let pngURL = URL(fileURLWithPath: "/path/to/image.png")
        #expect(ImageFormat.detectFormat(from: pngURL) == .png)
        
        let tiffURL = URL(fileURLWithPath: "/path/to/image.tiff")
        #expect(ImageFormat.detectFormat(from: tiffURL) == .tiff)
        
        let unknownURL = URL(fileURLWithPath: "/path/to/image.xyz")
        #expect(ImageFormat.detectFormat(from: unknownURL) == nil)
    }
    
    @Test func testImageFormatProperties() async throws {
        // Test lossy format detection
        #expect(ImageFormat.jpeg.isLossy == true)
        #expect(ImageFormat.jpg.isLossy == true)
        #expect(ImageFormat.webp.isLossy == true)
        #expect(ImageFormat.png.isLossy == false)
        #expect(ImageFormat.gif.isLossy == false)
        
        // Test display names
        #expect(ImageFormat.jpeg.displayName == "JPEG")
        #expect(ImageFormat.png.displayName == "PNG")
        #expect(ImageFormat.webp.displayName == "WebP")
        
        // Test file extensions
        #expect(ImageFormat.jpeg.fileExtension == "jpg")
        #expect(ImageFormat.tiff.fileExtension == "tif")
        #expect(ImageFormat.png.fileExtension == "png")
    }
    
    @Test func testImageFormatSets() async throws {
        // Test that input and output format sets are properly defined
        #expect(ImageFormat.inputFormats.contains(.jpeg))
        #expect(ImageFormat.inputFormats.contains(.png))
        #expect(ImageFormat.inputFormats.contains(.heic))
        
        #expect(ImageFormat.outputFormats.contains(.jpeg))
        #expect(ImageFormat.outputFormats.contains(.png))
        #expect(!ImageFormat.outputFormats.contains(.heic)) // HEIC might not be in output formats
    }
    
    // MARK: - Item Model Tests
    
    @Test func testItemCreation() async throws {
        let timestamp = Date()
        let item = Item(timestamp: timestamp)
        
        #expect(item.timestamp == timestamp)
    }
    
    @Test func testItemTimestampUpdate() async throws {
        let initialTimestamp = Date()
        let item = Item(timestamp: initialTimestamp)
        
        let newTimestamp = Date().addingTimeInterval(100)
        item.timestamp = newTimestamp
        
        #expect(item.timestamp == newTimestamp)
        #expect(item.timestamp != initialTimestamp)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testPandocErrors() async throws {
        // Test error descriptions
        let pandocNotInstalledError = PandocError.pandocNotInstalled
        #expect(pandocNotInstalledError.errorDescription?.contains("Pandoc is not installed") == true)
        #expect(pandocNotInstalledError.errorDescription?.contains("brew install pandoc") == true)
        
        let conversionFailedError = PandocError.conversionFailed("Test error message")
        #expect(conversionFailedError.errorDescription?.contains("Test error message") == true)
        
        let latexNotInstalledError = PandocError.latexNotInstalled
        #expect(latexNotInstalledError.errorDescription?.contains("LaTeX") == true)
        
        let outputDecodingError = PandocError.outputDecodingFailed
        #expect(outputDecodingError.errorDescription?.contains("decode") == true)
    }
    
    @Test func testImageMagickErrors() async throws {
        // Test error descriptions
        let imageMagickNotInstalledError = ImageMagickError.imageMagickNotInstalled
        #expect(imageMagickNotInstalledError.errorDescription?.contains("ImageMagick is not installed") == true)
        #expect(imageMagickNotInstalledError.errorDescription?.contains("brew install imagemagick") == true)
        
        let conversionFailedError = ImageMagickError.conversionFailed("Test error message")
        #expect(conversionFailedError.errorDescription?.contains("Test error message") == true)
    }
    
    // MARK: - ConversionHistoryManager Tests
    
    func createTestManager() -> ConversionHistoryManager {
        let manager = ConversionHistoryManager()
        manager.clearHistory() // Start with clean state
        return manager
    }
    
    @Test func testConversionHistoryManagerInit() async throws {
        let manager = createTestManager()
        #expect(manager.recentConversions.isEmpty)
    }
    
    @Test func testAddConversion() async throws {
        let manager = createTestManager()
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
        
        #expect(manager.recentConversions.count == 1)
        let record = manager.recentConversions.first!
        #expect(record.inputFileName == "test.md")
        #expect(record.inputFormat == "markdown")
        #expect(record.outputFormat == "pdf")
        #expect(record.outputFileName == "test.pdf")
    }
    
    @Test func testRemoveConversion() async throws {
        let manager = createTestManager()
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.pdf")
        
        try "Test content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        manager.addConversion(
            inputFileName: "test.md",
            inputFormat: "markdown",
            outputFormat: "pdf",
            outputFileURL: tempURL
        )
        
        let record = manager.recentConversions.first!
        manager.removeConversion(record)
        
        #expect(manager.recentConversions.isEmpty)
    }
    
    @Test func testClearHistory() async throws {
        let manager = createTestManager()
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.pdf")
        
        try "Test content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Add multiple conversions
        manager.addConversion(inputFileName: "test1.md", inputFormat: "markdown", outputFormat: "pdf", outputFileURL: tempURL)
        manager.addConversion(inputFileName: "test2.md", inputFormat: "markdown", outputFormat: "html", outputFileURL: tempURL)
        
        #expect(manager.recentConversions.count == 2)
        
        manager.clearHistory()
        #expect(manager.recentConversions.isEmpty)
    }
    
    @Test func testConversionRecordProperties() async throws {
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
        #expect(record.formattedFileSize.contains("bytes")) // Should contain bytes unit
        #expect(!record.formattedDate.isEmpty)
    }
    
    @Test func testHistoryMaxLimit() async throws {
        let manager = createTestManager()
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.pdf")
        
        try "Test content".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        // Add 55 conversions (more than the 50 limit)
        for i in 1...55 {
            manager.addConversion(
                inputFileName: "test\(i).md",
                inputFormat: "markdown",
                outputFormat: "pdf",
                outputFileURL: tempURL
            )
        }
        
        // Should be limited to 50
        #expect(manager.recentConversions.count == 50)
        // Most recent should be first
        #expect(manager.recentConversions.first?.inputFileName == "test55.md")
        #expect(manager.recentConversions.last?.inputFileName == "test6.md")
    }
    
    // MARK: - Integration Tests
    
    @Test func testFileExtensionHandling() async throws {
        // Test various file extension scenarios
        let extensions = ["md", "MD", "markdown", "MARKDOWN"]
        for ext in extensions {
            let url = URL(fileURLWithPath: "/test/file.\(ext)")
            #expect(PandocFormat.detectFormat(from: url) == .markdown)
        }
        
        let imageExtensions = ["jpg", "JPG", "jpeg", "JPEG"]
        for ext in imageExtensions {
            let url = URL(fileURLWithPath: "/test/image.\(ext)")
            let detected = ImageFormat.detectFormat(from: url)
            #expect(detected == .jpeg) // All JPEG variants detect as .jpeg (first match in enum)
        }
    }
}

// Test skip error for conditional tests
struct TestSkipError: Error {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
}
