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
    
    private var compatibleServices: [(ConversionService, String)] {
        guard !inputFileURLs.isEmpty else {
            // Return empty array when no files are present
            return []
        }
        
        // Check if all input files are PDFs
        let allPDFs = inputFileURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
        
        if allPDFs {
            // For PDF files, only show image format options
            let compatibleImageFormats = ImageFormat.outputFormats
            return compatibleImageFormats.map { format in 
                (.imagemagick(format), format.displayName)
            }.sorted { $0.1 < $1.1 }
        }
        
        // Detect if inputs are documents, images, or media files (excluding PDFs)
        let documentFormats = inputFileURLs.compactMap { url in
            url.pathExtension.lowercased() == "pdf" ? nil : PandocFormat.detectFormat(from: url)
        }
        let imageFormats = inputFileURLs.compactMap { url in
            url.pathExtension.lowercased() == "pdf" ? nil : ImageFormat.detectFormat(from: url)
        }
        let mediaFormats = inputFileURLs.compactMap { url in
            url.pathExtension.lowercased() == "pdf" ? nil : FFmpegFormat.detectFormat(from: url)
        }
        
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
        
        return compatibleServices.sorted { $0.1 < $1.1 }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Output Format", selection: $selectedService) {
                ForEach(compatibleServices, id: \.0) { service, name in
                    Text(name).tag(service)
                }
            }
            .pickerStyle(.menu)
            .disabled(inputFileURLs.isEmpty)
            
            // Format description
            Text(getFormatDescription(for: selectedService) ?? "")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 36, alignment: .topLeading)
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
        }
    }
    
    private func getFormatDescription(for service: ConversionService) -> String? {
        switch service {
        case .pandoc(let format):
            return format.description
        case .imagemagick(let format):
            return format.description
        case .ffmpeg(let format):
            return FormatRegistry.shared.config(for: format)?.description
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
        default:
            return false
        }
    }
}