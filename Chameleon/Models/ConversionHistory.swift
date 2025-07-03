//
//  ConversionHistory.swift
//  Chameleon
//
//  Created by Jakob Wells on 22.06.25.
//

import Foundation
import AppKit
import SwiftData

@Model
class ConversionRecord: @unchecked Sendable {
    var id: UUID
    var inputFileName: String
    var inputFormat: String
    var outputFormat: String
    var outputFileName: String
    var outputFileURL: URL
    var timestamp: Date
    var fileSize: Int64
    var thumbnailData: Data?

    init(inputFileName: String, inputFormat: String, outputFormat: String, outputFileName: String, outputFileURL: URL, timestamp: Date, fileSize: Int64, thumbnailData: Data? = nil) {
        self.id = UUID()
        self.inputFileName = inputFileName
        self.inputFormat = inputFormat
        self.outputFormat = outputFormat
        self.outputFileName = outputFileName
        self.outputFileURL = outputFileURL
        self.timestamp = timestamp
        self.fileSize = fileSize
        self.thumbnailData = thumbnailData
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var relativeTime: String {
        let now = Date()
        let interval = now.timeIntervalSince(timestamp)

        if interval < 60 {
            return "Just now"
        } else if interval < 3_600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86_400 {
            let hours = Int(interval / 3_600)
            return "\(hours)h ago"
        } else if interval < 604_800 {
            let days = Int(interval / 86_400)
            return "\(days)d ago"
        } else {
            let weeks = Int(interval / 604_800)
            return "\(weeks)w ago"
        }
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var isFileAccessible: Bool {
        FileManager.default.fileExists(atPath: outputFileURL.path)
    }

    var thumbnailImage: NSImage? {
        guard let data = thumbnailData else { return nil }
        return NSImage(data: data)
    }

    func generateThumbnailAsync() async -> Data? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .background).async {
                let thumbnailData = self.createThumbnail()
                continuation.resume(returning: thumbnailData)
            }
        }
    }

    private func createThumbnail() -> Data? {
        guard isFileAccessible else { return nil }

        // Try to create thumbnail from the actual file
        guard let image = NSImage(contentsOf: outputFileURL) else {
            return nil
        }

        let thumbnailSize = NSSize(width: 100, height: 100)
        let thumbnail = NSImage(size: thumbnailSize)

        thumbnail.lockFocus()

        // Set background based on file type
        let isPDF = outputFormat.lowercased() == "pdf"
        if isPDF {
            NSColor.white.setFill()
            NSRect(origin: .zero, size: thumbnailSize).fill()
        }

        // Calculate aspect-preserving rect
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        let targetAspect = thumbnailSize.width / thumbnailSize.height

        var drawRect: NSRect
        if imageAspect > targetAspect {
            // Image is wider, fit height and center horizontally
            let drawHeight = thumbnailSize.height
            let drawWidth = drawHeight * imageAspect
            let xOffset = (thumbnailSize.width - drawWidth) / 2
            drawRect = NSRect(x: xOffset, y: 0, width: drawWidth, height: drawHeight)
        } else {
            // Image is taller, fit width and center vertically
            let drawWidth = thumbnailSize.width
            let drawHeight = drawWidth / imageAspect
            let yOffset = (thumbnailSize.height - drawHeight) / 2
            drawRect = NSRect(x: 0, y: yOffset, width: drawWidth, height: drawHeight)
        }

        // Use appropriate composite operation based on file type
        let operation: NSCompositingOperation = isPDF ? .sourceOver : .copy
        image.draw(in: drawRect, from: NSRect(origin: .zero, size: imageSize), operation: operation, fraction: 1.0)

        thumbnail.unlockFocus()

        // Convert to JPEG data for storage
        guard let tiffData = thumbnail.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        return bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
    }
}
