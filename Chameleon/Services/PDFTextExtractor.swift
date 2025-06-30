//
//  PDFTextExtractor.swift
//  Chameleon
//
//  Created by Assistant on current date.
//

import Foundation
import PDFKit
import Vision
import AppKit

class PDFTextExtractor {
    
    enum ExtractionError: LocalizedError {
        case invalidPDF
        case noTextContent
        case extractionFailed(String)
        case ocrFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidPDF:
                return "Could not load PDF document"
            case .noTextContent:
                return "No text content found in PDF"
            case .extractionFailed(let message):
                return "Text extraction failed: \(message)"
            case .ocrFailed(let message):
                return "OCR failed: \(message)"
            }
        }
    }
    
    enum ExtractionMethod {
        case pdfKit  // Direct text extraction using PDFKit
        case vision  // OCR using Vision framework
    }
    
    static func extractText(from url: URL, method: ExtractionMethod = .pdfKit) async throws -> String {
        switch method {
        case .pdfKit:
            return try await extractTextUsingPDFKit(from: url)
        case .vision:
            return try await extractTextUsingVision(from: url)
        }
    }
    
    private static func extractTextUsingPDFKit(from url: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ExtractionError.invalidPDF
        }
        
        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw ExtractionError.noTextContent
        }
        
        var fullText = ""
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            if let pageText = page.string {
                // Add page separator if we already have text
                if !fullText.isEmpty {
                    fullText += "\n\n"
                }
                
                // Add page number header
                fullText += "--- Page \(pageIndex + 1) ---\n\n"
                
                // Add the page text
                fullText += pageText
            }
        }
        
        // Remove excessive whitespace and clean up
        fullText = fullText.replacingOccurrences(of: "\r\n", with: "\n")
        fullText = fullText.replacingOccurrences(of: "\r", with: "\n")
        
        // Remove multiple consecutive newlines (keep maximum 2)
        while fullText.contains("\n\n\n") {
            fullText = fullText.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        
        fullText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if fullText.isEmpty {
            throw ExtractionError.noTextContent
        }
        
        return fullText
    }
    
    private static func extractTextUsingVision(from url: URL) async throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ExtractionError.invalidPDF
        }
        
        let pageCount = pdfDocument.pageCount
        guard pageCount > 0 else {
            throw ExtractionError.noTextContent
        }
        
        var fullText = ""
        
        for pageIndex in 0..<pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else {
                continue
            }
            
            // Convert PDF page to image
            let pageRect = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2.0 // Higher resolution for better OCR
            
            let pageImage = NSImage(size: CGSize(width: pageRect.width * scale, height: pageRect.height * scale))
            
            pageImage.lockFocus()
            
            // Set up the graphics context
            let context = NSGraphicsContext.current?.cgContext
            context?.translateBy(x: 0, y: pageRect.height * scale)
            context?.scaleBy(x: scale, y: -scale)
            
            // Draw the PDF page
            page.draw(with: .mediaBox, to: context!)
            
            pageImage.unlockFocus()
            
            guard let cgImage = pageImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continue
            }
            
            // Perform OCR on the page image
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.automaticallyDetectsLanguage = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
                
                guard let observations = request.results else {
                    continue
                }
                
                // Extract text from observations
                let pageText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                if !pageText.isEmpty {
                    // Add page separator if we already have text
                    if !fullText.isEmpty {
                        fullText += "\n\n"
                    }
                    
                    // Add page number header
                    fullText += "--- Page \(pageIndex + 1) ---\n\n"
                    
                    // Add the page text
                    fullText += pageText
                }
                
            } catch {
                throw ExtractionError.ocrFailed("Failed to perform OCR on page \(pageIndex + 1): \(error.localizedDescription)")
            }
        }
        
        fullText = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if fullText.isEmpty {
            throw ExtractionError.noTextContent
        }
        
        return fullText
    }
}