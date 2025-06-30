//
//  PDFTextExtractor.swift
//  Chameleon
//
//  Created by Assistant on current date.
//

import Foundation
import PDFKit

class PDFTextExtractor {
    
    enum ExtractionError: LocalizedError {
        case invalidPDF
        case noTextContent
        case extractionFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidPDF:
                return "Could not load PDF document"
            case .noTextContent:
                return "No text content found in PDF"
            case .extractionFailed(let message):
                return "Text extraction failed: \(message)"
            }
        }
    }
    
    static func extractText(from url: URL) async throws -> String {
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
}