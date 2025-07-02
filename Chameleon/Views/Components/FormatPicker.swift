//
//  FormatPicker.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


import SwiftUI


struct FormatPicker: View {
    @Binding var selectedService: ConversionService
    let inputFileURLs: [URL]
    
    private var hasMediaFormats: Bool {
        compatibleServices.contains { service, _ in
            if case .ffmpeg = service {
                return true
            }
            if case .tts = service {
                return true
            }
            return false
        }
    }
    
    private var audioServices: [(ConversionService, String)] {
        compatibleServices.filter { service, _ in
            if case .ffmpeg(let format) = service {
                return !format.isVideo
            }
            if case .tts(_) = service {
                return true
            }
            return false
        }
    }
    
    private var videoServices: [(ConversionService, String)] {
        compatibleServices.filter { service, _ in
            if case .ffmpeg(let format) = service {
                return format.isVideo
            }
            return false
        }
    }
    
    private var nonMediaServices: [(ConversionService, String)] {
        compatibleServices.filter { service, _ in
            if case .ffmpeg = service {
                return false
            }
            if case .tts = service {
                return false
            }
            return true
        }
    }
    
    private var pdfImageFormats: [(ConversionService, String)] {
        guard inputFileURLs.allSatisfy({ $0.pathExtension.lowercased() == "pdf" }) else {
            return []
        }
        
        let imageFormats = ImageFormat.outputFormats.filter { format in
            // Include common image formats but exclude PDF itself
            let commonFormats: [ImageFormat] = [.jpeg, .png, .tiff, .webp, .bmp]
            return format != .pdf && commonFormats.contains(format)
        }
        
        return imageFormats.map { format in
            (ConversionService.imagemagick(format), format.displayName)
        }.sorted { $0.1 < $1.1 }
    }
    
    private var pdfDocumentFormats: [(ConversionService, String)] {
        guard inputFileURLs.allSatisfy({ $0.pathExtension.lowercased() == "pdf" }) else {
            return []
        }
        
        var formats: [(ConversionService, String)] = []
        
        // Add PDF merge/image option
        if inputFileURLs.count > 1 {
            formats.append((ConversionService.imagemagick(.pdf), "PDF (Merge)"))
        } else {
            formats.append((ConversionService.imagemagick(.pdf), "PDF (Image)"))
        }
        
        // Add text extraction options
        formats.append((ConversionService.ocr(.txtExtract), "Text (Extract)"))
        formats.append((ConversionService.ocr(.txtOCR), "Text (OCR)"))
        
        return formats
    }
    
    private var isPDFInput: Bool {
        inputFileURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
    }
    
    private var compatibleServices: [(ConversionService, String)] {
        guard !inputFileURLs.isEmpty else {
            // Return empty array when no files are present
            return []
        }
        
        // Check if all input files are PDFs
        let allPDFs = inputFileURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
        
        if allPDFs {
            // For PDF files, return empty here as we'll handle them in specialized properties
            return []
        }
        
        // Detect if inputs are documents, images, or media files
        let documentFormats = inputFileURLs.compactMap { PandocFormat.detectFormat(from: $0) }
        let imageFormats = inputFileURLs.compactMap { ImageFormat.detectFormat(from: $0) }
        let mediaFormats = inputFileURLs.compactMap { FFmpegFormat.detectFormat(from: $0) }
        
        var compatibleServices: [(ConversionService, String)] = []
        
        if !documentFormats.isEmpty {
            // Document conversion with Pandoc
            var compatiblePandocFormats = Set(PandocFormat.compatibleOutputFormats(for: documentFormats[0]))
            for format in documentFormats.dropFirst() {
                compatiblePandocFormats.formIntersection(PandocFormat.compatibleOutputFormats(for: format))
            }
            compatibleServices.append(contentsOf: compatiblePandocFormats.map { format in
                (.pandoc(format), format.displayName)
            })
        }
        
        if !imageFormats.isEmpty {
            // Image conversion with ImageMagick
            let compatibleImageFormats = ImageFormat.outputFormats
            compatibleServices.append(contentsOf: compatibleImageFormats.map { format in
                (.imagemagick(format), format.displayName)
            })
        }
        
        // Add OCR/Text extraction for mixed PDFs and images
        let hasPDFs = inputFileURLs.contains { url in
            url.pathExtension.lowercased() == "pdf"
        }
        let hasImages = !imageFormats.isEmpty
        
        if hasPDFs && hasImages {
            // Both PDFs and images: show generic text option
            compatibleServices.append((.ocr(.txt), "Text (OCR)"))
        } else if hasImages && !hasPDFs {
            // Only images: show text OCR option
            compatibleServices.append((.ocr(.txt), "Text (OCR)"))
        }
        
        if !mediaFormats.isEmpty {
            // Media conversion with FFmpeg
            let allInputsAreAudio = mediaFormats.allSatisfy { !$0.isVideo }
            let compatibleMediaFormats: [FFmpegFormat]
            
            if allInputsAreAudio {
                // If all inputs are audio, only show audio output formats
                compatibleMediaFormats = FFmpegFormat.allCases.filter { !$0.isVideo }
            } else {
                // If any input is video, show all formats
                compatibleMediaFormats = FFmpegFormat.allCases
            }
            
            compatibleServices.append(contentsOf: compatibleMediaFormats.compactMap { format in
                guard let config = FormatRegistry.shared.config(for: format) else { return nil }
                return (.ffmpeg(format), config.displayName)
            })
        }
        
        // Add TTS for text files
        let hasTextFiles = inputFileURLs.contains { url in
            let ext = url.pathExtension.lowercased()
            return ext == "txt" || ext == "text" || PandocFormat.detectFormat(from: url) == .plain
        }
        
        if hasTextFiles {
            // Add TTS audio output formats
            compatibleServices.append(contentsOf: TTSFormat.allCases.map { format in
                (.tts(format), "\(format.displayName) (TTS)")
            })
        }
        
        return compatibleServices.sorted { $0.1 < $1.1 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Output Format", selection: $selectedService) {
                if inputFileURLs.isEmpty {
                    // Show empty state
                    Text("").tag(selectedService)
                } else if isPDFInput {
                    // Special handling for PDF inputs
                    Section("Documents") {
                        ForEach(pdfDocumentFormats, id: \.0) { service, name in
                            Text(name).tag(service)
                        }
                    }
                    
                    Section("Images") {
                        ForEach(pdfImageFormats, id: \.0) { service, name in
                            Text(name).tag(service)
                        }
                    }
                } else if hasMediaFormats && nonMediaServices.isEmpty {
                    // Only media formats available
                    if !audioServices.isEmpty {
                        Section("Audio Formats") {
                            ForEach(audioServices, id: \.0) { service, name in
                                Text(name).tag(service)
                            }
                        }
                    }
                    
                    if !videoServices.isEmpty {
                        Section("Video Formats") {
                            ForEach(videoServices, id: \.0) { service, name in
                                Text(name).tag(service)
                            }
                        }
                    }
                } else if hasMediaFormats && !nonMediaServices.isEmpty {
                    // Mixed formats available (e.g., when selecting images that can be converted to video)
                    ForEach(nonMediaServices, id: \.0) { service, name in
                        Text(name).tag(service)
                    }
                    
                    if !audioServices.isEmpty || !videoServices.isEmpty {
                        Divider()
                        
                        if !audioServices.isEmpty {
                            Section("Audio Formats") {
                                ForEach(audioServices, id: \.0) { service, name in
                                    Text(name).tag(service)
                                }
                            }
                        }
                        
                        if !videoServices.isEmpty {
                            Section("Video Formats") {
                                ForEach(videoServices, id: \.0) { service, name in
                                    Text(name).tag(service)
                                }
                            }
                        }
                    }
                } else {
                    // No media formats, just show all compatible services
                    ForEach(compatibleServices, id: \.0) { service, name in
                        Text(name).tag(service)
                    }
                }
            }
            .pickerStyle(.menu)
            .disabled(inputFileURLs.isEmpty)
            
            // Format description
            Text(getFormatDescription(for: selectedService) ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 40, alignment: .topLeading)
        }
    }
    
    private func getServiceDisplayName(_ service: ConversionService) -> String {
        switch service {
        case .pandoc(let format):
            return format.displayName
        case .imagemagick(let format):
            return format.displayName
        case .ffmpeg(let format):
            return FormatRegistry.shared.config(for: format)?.displayName ?? format.rawValue.uppercased()
        case .ocr(let format):
            return format.displayName
        case .tts(let format):
            return FormatRegistry.shared.config(for: format)?.displayName ?? format.displayName
        }
    }
    
    private func getFormatDescription(for service: ConversionService) -> String? {
        switch service {
        case .pandoc(let format):
            return format.description
        case .imagemagick(let format):
            // Special description for PDF operations
            if format == .pdf && inputFileURLs.allSatisfy({ $0.pathExtension.lowercased() == "pdf" }) {
                if inputFileURLs.count > 1 {
                    return "Merge multiple PDF files into a single document while preserving all pages and formatting."
                } else {
                    return "Convert PDF to an image-based PDF. Useful for flattening forms, removing text layers, or ensuring consistent rendering."
                }
            }
            return format.description
        case .ffmpeg(let format):
            return FormatRegistry.shared.config(for: format)?.description
        case .ocr(let format):
            return format.description
        case .tts(let format):
            return FormatRegistry.shared.config(for: format)?.description ?? format.description
        }
    }
    
    private func servicesEqual(_ service1: ConversionService, _ service2: ConversionService) -> Bool {
        switch (service1, service2) {
        case (.pandoc(let f1), .pandoc(let f2)):
            return f1 == f2
        case (.imagemagick(let f1), .imagemagick(let f2)):
            return f1 == f2
        case (.ffmpeg(let f1), .ffmpeg(let f2)):
            return f1 == f2
        case (.ocr(let f1), .ocr(let f2)):
            return f1 == f2
        default:
            return false
        }
    }
}
