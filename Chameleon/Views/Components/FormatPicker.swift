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
    let isPandocAvailable: Bool
    let isImageMagickAvailable: Bool
    let isFFmpegAvailable: Bool

    private var pdfImageFormats: [(ConversionService, String)] {
        guard inputFileURLs.allSatisfy({ $0.pathExtension.lowercased() == "pdf" }) && isImageMagickAvailable else {
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

        // Add PDF merge/image option (can use native PDF operations)
        if inputFileURLs.count > 1 {
            formats.append((ConversionService.imagemagick(.pdf), "PDF (Merge)"))
        } else {
            formats.append((ConversionService.imagemagick(.pdf), "PDF (Image)"))
        }

        // Add text extraction options (always available as they're internal)
        formats.append((ConversionService.ocr(.txtExtract), "Text (Extract)"))
        formats.append((ConversionService.ocr(.txtOCR), "Text (OCR)"))

        return formats
    }

    // New computed properties for consistent sectioning
    private var documentOutputServices: [(ConversionService, String)] {
        compatibleServices.filter { service, _ in
            switch service {
            case .pandoc:
                return true
            case .imagemagick(let format) where format == .pdf:
                return true
            case .ocr:
                return true
            default:
                return false
            }
        }
    }

    private var imageOutputServices: [(ConversionService, String)] {
        compatibleServices.filter { service, _ in
            if case .imagemagick(let format) = service {
                return format != .pdf
            }
            return false
        }
    }

    private var audioOutputServices: [(ConversionService, String)] {
        compatibleServices.filter { service, _ in
            switch service {
            case .ffmpeg(let format) where !format.isVideo:
                return true
            case .tts:
                return true
            default:
                return false
            }
        }
    }

    private var videoOutputServices: [(ConversionService, String)] {
        compatibleServices.filter { service, _ in
            if case .ffmpeg(let format) = service {
                return format.isVideo
            }
            return false
        }
    }

    private var archiveOutputServices: [(ConversionService, String)] {
        compatibleServices.filter { service, _ in
            if case .archive = service {
                return true
            }
            return false
        }
    }

    private var compatibleServices: [(ConversionService, String)] {
        guard !inputFileURLs.isEmpty else {
            // Return empty array when no files are present
            return []
        }

        // Check if all input files are PDFs
        let allPDFs = inputFileURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" }

        if allPDFs {
            // For PDF files, use the specialized properties
            return pdfDocumentFormats + pdfImageFormats
        }

        // Detect if inputs are documents, images, or media files
        let documentFormats = inputFileURLs.compactMap { PandocFormat.detectFormat(from: $0) }
        let imageFormats = inputFileURLs.compactMap { ImageFormat.detectFormat(from: $0) }
        let mediaFormats = inputFileURLs.compactMap { FFmpegFormat.detectFormat(from: $0) }

        var compatibleServices: [(ConversionService, String)] = []

        if !documentFormats.isEmpty && isPandocAvailable {
            // Document conversion with Pandoc (only if available)
            var compatiblePandocFormats = Set(PandocFormat.compatibleOutputFormats(for: documentFormats[0]))
            for format in documentFormats.dropFirst() {
                compatiblePandocFormats.formIntersection(PandocFormat.compatibleOutputFormats(for: format))
            }
            compatibleServices.append(contentsOf: compatiblePandocFormats.map { format in
                (.pandoc(format), format.displayName)
            })
        }

        if !imageFormats.isEmpty && isImageMagickAvailable {
            // Image conversion with ImageMagick (only if available)
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

        if !mediaFormats.isEmpty && isFFmpegAvailable {
            // Media conversion with FFmpeg (only if available)
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
            let isPlainText = ext == "txt" || ext == "text"
            let isPandocPlainText = isPandocAvailable && PandocFormat.detectFormat(from: url) == .plain
            return isPlainText || isPandocPlainText
        }

        if hasTextFiles {
            // Add TTS audio output formats
            compatibleServices.append(contentsOf: TTSFormat.allCases.map { format in
                (.tts(format), "\(format.displayName) (TTS)")
            })
        }

        // Add archive formats - available for any files
        compatibleServices.append(contentsOf: ArchiveFormat.allCases.map { format in
            (.archive(format), format.displayName)
        })

        return compatibleServices.sorted { $0.1 < $1.1 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Output Format", selection: $selectedService) {
                if inputFileURLs.isEmpty {
                    // Show empty state
                    Text("").tag(selectedService)
                } else {
                    // Count how many sections have content
                    let sectionsWithContent = [
                        !documentOutputServices.isEmpty,
                        !imageOutputServices.isEmpty,
                        !audioOutputServices.isEmpty,
                        !videoOutputServices.isEmpty,
                        !archiveOutputServices.isEmpty
                    ].filter { $0 }.count

                    // If only one section has content, show without section headers
                    if sectionsWithContent == 1 {
                        ForEach(compatibleServices, id: \.0) { service, name in
                            Text(name).tag(service)
                        }
                    } else {
                        // Show with sections
                        if !documentOutputServices.isEmpty {
                            Section("Document Formats") {
                                ForEach(documentOutputServices, id: \.0) { service, name in
                                    Text(name).tag(service)
                                }
                            }
                        }

                        if !imageOutputServices.isEmpty {
                            Section("Image Formats") {
                                ForEach(imageOutputServices, id: \.0) { service, name in
                                    Text(name).tag(service)
                                }
                            }
                        }

                        if !audioOutputServices.isEmpty {
                            Section("Audio Formats") {
                                ForEach(audioOutputServices, id: \.0) { service, name in
                                    Text(name).tag(service)
                                }
                            }
                        }

                        if !videoOutputServices.isEmpty {
                            Section("Video Formats") {
                                ForEach(videoOutputServices, id: \.0) { service, name in
                                    Text(name).tag(service)
                                }
                            }
                        }

                        if !archiveOutputServices.isEmpty {
                            Section("Archive Formats") {
                                ForEach(archiveOutputServices, id: \.0) { service, name in
                                    Text(name).tag(service)
                                }
                            }
                        }

                    }
                }
            }
            .pickerStyle(.menu)
            .disabled(inputFileURLs.isEmpty)
            .onAppear {
                // Check if the currently selected service is a Pandoc format and Pandoc is not available
                if case .pandoc = selectedService, !isPandocAvailable {
                    // Switch to the first available format
                    if let firstService = compatibleServices.first?.0 {
                        selectedService = firstService
                    }
                }
            }
            .onChange(of: isPandocAvailable) { _, newValue in
                // If Pandoc becomes unavailable and current selection is a Pandoc format
                if case .pandoc = selectedService, !newValue {
                    // Switch to the first available format
                    if let firstService = compatibleServices.first?.0 {
                        selectedService = firstService
                    }
                }
            }

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
        case .archive(let format):
            return format.displayName
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
                    return "Convert PDF to an image-based PDF. Useful for flattening forms, " +
                           "removing text layers, or ensuring consistent rendering."
                }
            }
            return format.description
        case .ffmpeg(let format):
            return FormatRegistry.shared.config(for: format)?.description
        case .ocr(let format):
            return format.description
        case .tts(let format):
            return FormatRegistry.shared.config(for: format)?.description ?? format.description
        case .archive(let format):
            return format.description
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
        case (.archive(let f1), .archive(let f2)):
            return f1 == f2
        default:
            return false
        }
    }
}
