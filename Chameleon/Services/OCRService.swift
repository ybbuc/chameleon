//
//  OCRService.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import Foundation
import Vision
import AppKit

class OCRService {
    enum OCRError: LocalizedError {
        case imageLoadingFailed
        case textRecognitionFailed(String)
        case noTextFound
        
        var errorDescription: String? {
            switch self {
            case .imageLoadingFailed:
                return "Failed to load image for OCR processing"
            case .textRecognitionFailed(let message):
                return "Text recognition failed: \(message)"
            case .noTextFound:
                return "No text was found in the image"
            }
        }
    }
    
    enum RecognitionLevel: String, CaseIterable {
        case fast = "Fast"
        case accurate = "Accurate"
        
        var visionLevel: VNRequestTextRecognitionLevel {
            switch self {
            case .fast: return .fast
            case .accurate: return .accurate
            }
        }
    }
    
    struct Options {
        var recognitionLevel: RecognitionLevel = .accurate
        var recognitionLanguages: [String] = ["automatic"] // Default to automatic language detection
        var usesLanguageCorrection: Bool = false
        var minimumTextHeight: Float = 0.0 // 0.0 means no minimum
        var customWords: [String] = []
    }
    
    private var currentRequest: VNRecognizeTextRequest?
    
    func recognizeText(from imageURL: URL, options: Options = Options()) async throws -> String {
        guard let image = NSImage(contentsOf: imageURL) else {
            throw OCRError.imageLoadingFailed
        }
        
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw OCRError.imageLoadingFailed
        }
        
        return try await recognizeText(from: cgImage, options: options)
    }
    
    func recognizeText(from cgImage: CGImage, options: Options = Options()) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = options.recognitionLevel.visionLevel
        
        // Handle "automatic" language option
        if options.recognitionLanguages.contains("automatic") {
            request.automaticallyDetectsLanguage = true
        } else {
            request.recognitionLanguages = options.recognitionLanguages
            request.automaticallyDetectsLanguage = false
        }
        
        request.usesLanguageCorrection = options.usesLanguageCorrection
        request.minimumTextHeight = options.minimumTextHeight
        request.customWords = options.customWords
        
        currentRequest = request
        defer { currentRequest = nil }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            throw OCRError.textRecognitionFailed(error.localizedDescription)
        }
        
        guard let observations = request.results else {
            throw OCRError.noTextFound
        }
        
        if observations.isEmpty {
            throw OCRError.noTextFound
        }
        
        // Extract text maintaining paragraph structure
        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }
        
        return recognizedStrings.joined(separator: "\n")
    }
    
    struct Language: Identifiable, Hashable {
        let id: String  // Language code (e.g., "en-US")
        let displayName: String
        
        static let supportedLanguages: [Language] = [
            Language(id: "automatic", displayName: "Automatic"),
            Language(id: "en-US", displayName: "English"),
            Language(id: "fr-FR", displayName: "French"),
            Language(id: "it-IT", displayName: "Italian"),
            Language(id: "de-DE", displayName: "German"),
            Language(id: "es-ES", displayName: "Spanish"),
            Language(id: "pt-BR", displayName: "Portuguese"),
            Language(id: "zh-Hans", displayName: "Chinese (Simplified)"),
            Language(id: "zh-Hant", displayName: "Chinese (Traditional)"),
            Language(id: "yue-Hans", displayName: "Cantonese (Simplified)"),
            Language(id: "yue-Hant", displayName: "Cantonese (Traditional)"),
            Language(id: "ko-KR", displayName: "Korean"),
            Language(id: "ja-JP", displayName: "Japanese"),
            Language(id: "ru-RU", displayName: "Russian"),
            Language(id: "uk-UA", displayName: "Ukrainian"),
            Language(id: "th-TH", displayName: "Thai"),
            Language(id: "vi-VT", displayName: "Vietnamese"),
            Language(id: "ar-SA", displayName: "Arabic"),
            Language(id: "ars-SA", displayName: "Arabic (Saudi)")
        ]
    }
    
    func cancel() {
        // Vision framework doesn't support cancellation directly
        currentRequest = nil
    }
}

// OCR output format options
enum OCRFormat: String, CaseIterable {
    case txt = "txt"
    
    var displayName: String {
        switch self {
        case .txt: return "Plain Text"
        }
    }
    
    var fileExtension: String {
        return self.rawValue
    }
    
    var description: String {
        switch self {
        case .txt:
            return "Use text recognition to extract text from images and save as plain text files."
        }
    }
}
