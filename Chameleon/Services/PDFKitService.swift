import Foundation
import PDFKit
import AppKit
import UniformTypeIdentifiers

class PDFKitService {

    struct PDFConversionOptions {
        let scale: CGFloat
        let format: ImageFormat
        let backgroundColor: NSColor
        let jpegQuality: CGFloat

        enum ImageFormat: String, CaseIterable {
            case png = "PNG"
            case jpeg = "JPEG"
            case tiff = "TIFF"

            var fileExtension: String {
                switch self {
                case .png: return "png"
                case .jpeg: return "jpg"
                case .tiff: return "tiff"
                }
            }

            var utType: UTType {
                switch self {
                case .png: return .png
                case .jpeg: return .jpeg
                case .tiff: return .tiff
                }
            }
        }

        init(scale: CGFloat = 2.0, format: ImageFormat = .png, backgroundColor: NSColor = .white, jpegQuality: CGFloat = 0.9) {
            self.scale = scale
            self.format = format
            self.backgroundColor = backgroundColor
            self.jpegQuality = jpegQuality
        }
    }

    static func convertPDFToImages(at url: URL, outputDirectory: URL, options: PDFConversionOptions = PDFConversionOptions()) async throws -> [URL] {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ConversionError.invalidInput("Could not load PDF document")
        }

        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw ConversionError.invalidInput("PDF document has no pages")
        }

        var outputURLs: [URL] = []
        let baseFileName = url.deletingPathExtension().lastPathComponent

        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }

            // Get the page bounds
            let pageBounds = page.bounds(for: .mediaBox)
            let scaledSize = NSSize(
                width: pageBounds.width * options.scale,
                height: pageBounds.height * options.scale
            )

            // Create the scaled image
            let scaledImage = NSImage(size: scaledSize)
            scaledImage.lockFocus()

            // Fill background
            options.backgroundColor.setFill()
            NSRect(origin: .zero, size: scaledSize).fill()

            // Create an image from the PDF page
            NSGraphicsContext.saveGraphicsState()

            // Set up the transform to scale the PDF page
            let transform = NSAffineTransform()
            transform.scale(by: options.scale)
            transform.concat()

            // Draw the PDF page
            if let context = NSGraphicsContext.current?.cgContext {
                page.draw(with: .mediaBox, to: context)
            }

            NSGraphicsContext.restoreGraphicsState()

            scaledImage.unlockFocus()

            // Convert NSImage to data
            guard let tiffData = scaledImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else {
                throw ConversionError.conversionFailed("Failed to create bitmap representation")
            }

            // Get image data in the requested format
            let imageData: Data?
            switch options.format {
            case .png:
                imageData = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:])
            case .jpeg:
                imageData = bitmap.representation(using: NSBitmapImageRep.FileType.jpeg, properties: [NSBitmapImageRep.PropertyKey.compressionFactor: options.jpegQuality])
            case .tiff:
                imageData = bitmap.representation(using: NSBitmapImageRep.FileType.tiff, properties: [:])
            }

            guard let data = imageData else {
                throw ConversionError.conversionFailed("Failed to create \(options.format.rawValue) data")
            }

            // Save the image
            let pageNumberString = pageCount > 1 ? "_page_\(String(format: "%03d", pageIndex + 1))" : ""
            let outputFileName = "\(baseFileName)\(pageNumberString).\(options.format.fileExtension)"
            let outputURL = outputDirectory.appendingPathComponent(outputFileName)

            try data.write(to: outputURL)
            outputURLs.append(outputURL)
        }

        return outputURLs
    }

    static func combinePDFs(at urls: [URL], outputURL: URL) async throws {
        guard !urls.isEmpty else {
            throw ConversionError.invalidInput("No PDF files provided")
        }

        // Create a new PDF document
        let outputDocument = PDFDocument()
        var pageIndex = 0

        // Process each input PDF
        for (fileIndex, url) in urls.enumerated() {
            guard let pdfDocument = PDFDocument(url: url) else {
                throw ConversionError.invalidInput("Could not load PDF document at index \(fileIndex): \(url.lastPathComponent)")
            }

            // Add all pages from this PDF to the output document
            for sourcePageIndex in 0..<pdfDocument.pageCount {
                guard let page = pdfDocument.page(at: sourcePageIndex) else {
                    continue
                }

                // Insert the page at the current index
                outputDocument.insert(page, at: pageIndex)
                pageIndex += 1
            }
        }

        // Ensure we have at least one page
        guard outputDocument.pageCount > 0 else {
            throw ConversionError.conversionFailed("No pages found in input PDFs")
        }

        // Write the combined PDF to the output URL
        guard outputDocument.write(to: outputURL) else {
            throw ConversionError.conversionFailed("Failed to write combined PDF to output")
        }
    }

    enum ConversionError: LocalizedError {
        case invalidInput(String)
        case conversionFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidInput(let message):
                return "Invalid input: \(message)"
            case .conversionFailed(let message):
                return "Conversion failed: \(message)"
            }
        }
    }
}
