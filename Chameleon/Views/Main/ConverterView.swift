//
//  ConverterView.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit
import ActivityIndicatorView
import ProgressIndicatorView


struct ConverterView: View {
    @ObservedObject var savedHistoryManager: SavedHistoryManager
    @State private var files: [FileState] = []
    @State private var outputService: ConversionService = .pandoc(.html)
    @State private var isConverting = false
    @State private var currentConversionFile = ""
    @State private var conversionProgress = (current: 0, total: 0)
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @AppStorage("imageQuality") private var imageQuality: Double = 85
    @AppStorage("useLossyCompression") private var useLossyCompression: Bool = false
    @AppStorage("removeExifMetadata") private var removeExifMetadata: Bool = false
    @State private var isTargeted = false
    @State private var dashPhase: CGFloat = 0
    @AppStorage("pdfToDpi") private var pdfToDpi: Int = 300
    @State private var audioOptions = AudioOptions()
    
    @State private var pandocWrapper: PandocWrapper?
    @State private var pandocInitError: String?
    @State private var imageMagickWrapper: ImageMagickWrapper?
    @State private var imageMagickInitError: String?
    @State private var ffmpegWrapper: FFmpegWrapper?
    @State private var ffmpegInitError: String?
    @State private var conversionTask: Task<Void, Never>?
    
    private let completionSound: NSSound? = {
        guard let soundURL = Bundle.main.url(forResource: "complete", withExtension: "aac") else {
            print("Could not find completion.aac in bundle")
            return nil
        }
        return NSSound(contentsOf: soundURL, byReference: true)
    }()
    
    private let failureSound: NSSound? = {
        guard let soundURL = Bundle.main.url(forResource: "fail", withExtension: "aac") else {
            print("Could not find failure.aac in bundle")
            return nil
        }
        return NSSound(contentsOf: soundURL, byReference: true)
    }()
    
    
    // MARK: - File pane
    var body: some View {
        HStack(spacing: 0) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isTargeted ? Color.accentColor : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 2, dash: [8, 8]))
                                .animation(.easeInOut(duration: 0.2), value: isTargeted)
                        )
                        .shadow(color: isTargeted ? Color.accentColor.opacity(0.4) : Color.clear, radius: isTargeted ? 12 : 0)
                        .animation(.easeInOut(duration: 0.2), value: isTargeted)
                    
                    if !files.isEmpty {
                        if files.count == 1 {
                            let fileState = files[0]
                            VStack(spacing: 0) {
                                VStack(spacing: 12) {
                                    
                                    ZStack {
                                        switch fileState {
                                        case .input(let url):
                                            FilePreviewView(url: url)
                                        case .converting(let url, _):
                                            FilePreviewView(url: url)
                                        case .converted(let convertedFile):
                                            FilePreviewView(data: convertedFile.data, fileName: convertedFile.fileName)
                                        case .error(let url, _):
                                            FilePreviewView(url: url)
                                        }
                                        
                                        if case .converting = fileState {
                                            Rectangle()
                                                .fill(Color.black.opacity(0.6))
                                                .overlay(
                                                    ActivityIndicatorView(isVisible: .constant(true), type: .scalingDots(count: 3, inset: 4))
                                                        .frame(width: 40, height: 20)
                                                        .foregroundStyle(.white)
                                                )
                                        }
                                    }
                                    
                                    Text(fileState.fileName)
                                        .font(.headline)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    
                                    if case .error(_, let message) = fileState {
                                        Text(message)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                if case .converting = fileState {
                                    VStack(spacing: 0) {
                                        Divider()
                                            .padding(.horizontal)
                                        
                                        HStack(spacing: 12) {
                                            ResetButton(
                                                label: "Reset",
                                                isDisabled: true
                                            ) {
                                                files = []
                                                errorMessage = nil
                                            }
                                            
                                            if let url = fileState.url {
                                                PreviewButton(action: {
                                                    QuickLookManager.shared.previewFile(at: url)
                                                })
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                    }
                                } else {
                                    VStack(spacing: 0) {
                                        Divider()
                                            .padding(.horizontal)
                                        
                                        HStack(spacing: 12) {
                                            switch fileState {
                                            case .input(let url):
                                                ResetButton(
                                                    label: "Reset",
                                                    isDisabled: false
                                                ) {
                                                    files = []
                                                    errorMessage = nil
                                                }
                                                
                                                PreviewButton(action: {
                                                    QuickLookManager.shared.previewFile(at: url)
                                                })
                                            case .converting:
                                                EmptyView()
                                            case .converted(let convertedFile):
                                                ResetButton(
                                                    label: "Reset",
                                                    isDisabled: false
                                                ) {
                                                    files = []
                                                    errorMessage = nil
                                                }
                                                
                                                PreviewButton(action: {
                                                    QuickLookManager.shared.previewFile(data: convertedFile.data, fileName: convertedFile.fileName)
                                                })
                                                
                                                SaveAllButton(
                                                    label: "Save"
                                                ) {
                                                    saveFile(data: convertedFile.data, fileName: convertedFile.fileName, originalURL: convertedFile.originalURL)
                                                }
                                            case .error:
                                                ResetButton(
                                                    label: "Reset",
                                                    isDisabled: false
                                                ) {
                                                    files = []
                                                    errorMessage = nil
                                                }
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                    }
                                }
                            }
                        } else {
                            VStack(spacing: 0) {
                                ScrollView {
                                    VStack(spacing: 0) {
                                        ForEach(files) { fileState in
                                            fileRow(for: fileState)
                                            
                                            if fileState.id != files.last?.id {
                                                Divider()
                                                    .padding(.horizontal, 12)
                                            }
                                        }
                                    }
                                    .padding(8)
                                }
                                .padding(8)
                                
                                VStack(spacing: 0) {
                                    Divider()
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 12) {
                                        ResetButton(
                                            label: "Reset",
                                            isDisabled: false
                                        ) {
                                            files = []
                                            errorMessage = nil
                                        }
                                        
                                        let convertedCount = files.filter { if case .converted = $0 { true } else { false } }.count
                                        SaveAllButton(
                                            label: convertedCount == 1 ? "Save" : "Save All"
                                        ) {
                                            saveAllFiles()
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.secondary.opacity(0.3))
                            
                            Text("Drop Files Here")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Button("Browse…") {
                                selectFile()
                            }
                            .buttonStyle(.bordered)
                            
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                    handleDrop(providers: providers)
                }
                
                
                if pandocWrapper == nil {
                    Text("✗ Pandoc not available")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            
            // MARK: - Convert pane
            VStack {
                FormatPicker(selectedService: $outputService, inputFileURLs: files.compactMap { $0.url })
                    .padding(.top)
                    .disabled(files.isEmpty || files.contains(where: { if case .converting = $0 { true } else { false } }))
                
                // Show DPI selector when converting PDF to image
                if shouldShowDpiSelector {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("PDF Resolution")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(pdfToDpi) DPI")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        VStack(spacing: 4) {
                            Slider(
                                value: Binding(
                                    get: { Double(pdfToDpiIndex) },
                                    set: { newValue in
                                        let dpiValues = [72, 150, 300, 600, 1200]
                                        let index = Int(newValue)
                                        pdfToDpi = dpiValues[min(max(0, index), dpiValues.count - 1)]
                                    }
                                ),
                                in: 0...5,
                                step: 1
                            )
                        }
                        
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: shouldShowDpiSelector)
                }
                
                // Show EXIF metadata removal toggle for image conversions (but not PDFs)
                if shouldShowExifOption {
                    HStack {
                        Spacer()
                        Toggle("Strip EXIF Metadata", isOn: $removeExifMetadata)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: shouldShowExifOption)
                }
                
                // Show quality controls for lossy image conversions
                if case .imagemagick(let format) = outputService, !files.isEmpty, format.isLossy {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Spacer()
                            Toggle("Lossy Compression", isOn: $useLossyCompression)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                            
                        }
                        
                        HStack {
                            Text("Image Quality")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(useLossyCompression ? "\(Int(imageQuality))" : "Default")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                        
                        VStack(spacing: 4) {
                            Slider(value: $imageQuality,
                                    in: 1...100,
                                    minimumValueLabel: Text("1").font(.caption2),
                                    maximumValueLabel: Text("100").font(.caption2),
                                    label: {
                                        Text("Quality")
                                    }
                                )
                            .labelsHidden()
                            .disabled(!useLossyCompression)
                        }
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: outputService)
                }
                
                // Show audio options for FFmpeg audio conversions
                if shouldShowAudioOptions {
                    AudioOptionsView(audioOptions: $audioOptions, outputFormat: currentFFmpegFormat)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.2), value: outputService)
                }
                
                Spacer()
                
                VStack {
                    if isConverting {
                        Button(action: {
                            cancelConversion()
                        }) {
                            Text("Cancel")
                                .font(.title3)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.bottom)
                    } else {
                        Button(action: {
                            print("Convert button clicked")
                            conversionTask = Task {
                                await convertFile()
                            }
                        }) {
                            Label("Convert", systemImage: "arrowshape.zigzag.right")
                                .font(.title3)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .disabled(files.isEmpty || !isConversionServiceAvailable() || files.contains(where: { if case .converting = $0 { true } else { false } }) || !files.contains(where: { if case .input = $0 { true } else { false } }))
                        .controlSize(.large)
                        .padding(.bottom)
                    }
                }
            }
            .padding()
            .frame(width: 300)
            
        }
        .onAppear {
            initializePandoc()
            initializeImageMagick()
            initializeFFmpeg()
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Initialization Error", isPresented: Binding<Bool>(
            get: { pandocInitError != nil },
            set: { _ in pandocInitError = nil }
        )) {
            Button("OK") { 
                pandocInitError = nil
            }
        } message: {
            Text(pandocInitError ?? "")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
    
    private func cancelConversion() {
        // Cancel the Task
        conversionTask?.cancel()
        conversionTask = nil
        
        // Cancel any running processes
        pandocWrapper?.cancel()
        imageMagickWrapper?.cancel()
        ffmpegWrapper?.cancel()
        
        // Reset conversion state
        isConverting = false
        currentConversionFile = ""
        conversionProgress = (current: 0, total: 0)
        
        // Reset any converting files back to input state
        for i in files.indices {
            if case .converting(let url, _) = files[i] {
                files[i] = .input(url)
            }
        }
    }
    
    private func initializePandoc() {
        do {
            print("Attempting to initialize PandocWrapper...")
            pandocWrapper = try PandocWrapper()
            pandocInitError = nil
            print("PandocWrapper initialized successfully")
        } catch {
            print("PandocWrapper initialization failed: \(error)")
            pandocWrapper = nil
            pandocInitError = error.localizedDescription
        }
    }
    
    private func initializeImageMagick() {
        do {
            print("Attempting to initialize ImageMagick...")
            imageMagickWrapper = try ImageMagickWrapper()
            imageMagickInitError = nil
            print("ImageMagick initialized successfully")
        } catch {
            print("ImageMagick initialization failed: \(error)")
            imageMagickWrapper = nil
            imageMagickInitError = error.localizedDescription
        }
    }
    
    private func initializeFFmpeg() {
        do {
            print("Attempting to initialize FFmpeg...")
            ffmpegWrapper = try FFmpegWrapper()
            ffmpegInitError = nil
            print("FFmpeg initialized successfully")
        } catch {
            print("FFmpeg initialization failed: \(error)")
            ffmpegWrapper = nil
            ffmpegInitError = error.localizedDescription
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data,
                       let path = String(data: urlData, encoding: .utf8),
                       let url = URL(string: path) {
                        
                        // Check if file already exists
                        if self.files.contains(where: { $0.url == url }) {
                            return
                        }
                        
                        guard self.isSupportedFileType(url) else {
                            self.showError("Unsupported file type: \(url.pathExtension)")
                            return
                        }
                        
                        // If this is the first file, allow it
                        if self.files.isEmpty {
                            self.files.append(.input(url))
                            self.errorMessage = nil
                            self.updateOutputService()
                            return
                        }
                        
                        // Check if the new file is compatible with existing files
                        let existingURLs = self.files.compactMap { $0.url }
                        let existingDocumentFormats = existingURLs.compactMap { PandocFormat.detectFormat(from: $0) }
                        let existingImageFormats = existingURLs.compactMap { ImageFormat.detectFormat(from: $0) }
                        let existingMediaFormats = existingURLs.compactMap { FFmpegFormat.detectFormat(from: $0) }
                        
                        let newDocumentFormat = PandocFormat.detectFormat(from: url)
                        let newImageFormat = ImageFormat.detectFormat(from: url)
                        let newMediaFormat = FFmpegFormat.detectFormat(from: url)
                        
                        let isNewDocument = newDocumentFormat != nil
                        let isNewImage = newImageFormat != nil
                        let isNewMedia = newMediaFormat != nil
                        let hasExistingDocuments = !existingDocumentFormats.isEmpty
                        let hasExistingImages = !existingImageFormats.isEmpty
                        let hasExistingMedia = !existingMediaFormats.isEmpty
                        
                        // Allow if new file type matches existing file types
                        if (isNewDocument && hasExistingDocuments && !hasExistingImages && !hasExistingMedia) ||
                           (isNewImage && hasExistingImages && !hasExistingDocuments && !hasExistingMedia) ||
                           (isNewMedia && hasExistingMedia && !hasExistingDocuments && !hasExistingImages) {
                            self.files.append(.input(url))
                            self.errorMessage = nil
                            self.updateOutputService()
                        } else {
                            // Replace existing files with the new incompatible file
                            self.files = [.input(url)]
                            self.errorMessage = nil
                            self.updateOutputService()
                        }
                    }
                }
            }
        }
        
        return true
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            // Document types
            .text, .plainText, .sourceCode, .html,
            UTType(filenameExtension: "md")!,
            UTType(filenameExtension: "tex")!,
            UTType(filenameExtension: "rst")!,
            UTType(filenameExtension: "org")!,
            UTType(filenameExtension: "docx")!,
            UTType(filenameExtension: "odt")!,
            UTType(filenameExtension: "epub")!,
            // Image types
            .image, .jpeg, .png, .gif, .bmp, .tiff, .pdf,
            UTType(filenameExtension: "webp")!,
            UTType(filenameExtension: "heic")!,
            UTType(filenameExtension: "heif")!,
            UTType(filenameExtension: "svg")!,
            UTType(filenameExtension: "ico")!
        ]
        
        if panel.runModal() == .OK {
            for url in panel.urls {
                // Check if file already exists
                if files.contains(where: { $0.url == url }) {
                    continue
                }
                
                guard isSupportedFileType(url) else {
                    showError("Unsupported file type: \(url.pathExtension)")
                    continue
                }
                
                // If this is the first file, allow it
                if files.isEmpty {
                    files.append(.input(url))
                    updateOutputService()
                    continue
                }
                
                // Check if the new file is compatible with existing files
                let existingURLs = files.compactMap { $0.url }
                let existingDocumentFormats = existingURLs.compactMap { PandocFormat.detectFormat(from: $0) }
                let existingImageFormats = existingURLs.compactMap { ImageFormat.detectFormat(from: $0) }
                let existingMediaFormats = existingURLs.compactMap { FFmpegFormat.detectFormat(from: $0) }
                
                let newDocumentFormat = PandocFormat.detectFormat(from: url)
                let newImageFormat = ImageFormat.detectFormat(from: url)
                let newMediaFormat = FFmpegFormat.detectFormat(from: url)
                
                let isNewDocument = newDocumentFormat != nil
                let isNewImage = newImageFormat != nil
                let isNewMedia = newMediaFormat != nil
                let hasExistingDocuments = !existingDocumentFormats.isEmpty
                let hasExistingImages = !existingImageFormats.isEmpty
                let hasExistingMedia = !existingMediaFormats.isEmpty
                
                // Allow if new file type matches existing file types
                if (isNewDocument && hasExistingDocuments && !hasExistingImages && !hasExistingMedia) ||
                   (isNewImage && hasExistingImages && !hasExistingDocuments && !hasExistingMedia) ||
                   (isNewMedia && hasExistingMedia && !hasExistingDocuments && !hasExistingImages) {
                    files.append(.input(url))
                    updateOutputService()
                } else {
                    // Replace existing files with the new incompatible file
                    files = [.input(url)]
                    errorMessage = nil
                    updateOutputService()
                    break
                }
            }
            
            if errorMessage == nil {
                errorMessage = nil // Clear any previous errors if successful
            }
        }
    }
    
    private func convertFile() async {
        let inputURLs = files.compactMap { fileState in
            if case .input(let url) = fileState {
                return url
            }
            return nil
        }
        guard !inputURLs.isEmpty else {
            print("convertFile: no input files")
            return
        }
        
        // Track if we've played the failure sound
        var hasPlayedFailureSound = false
        
        // Check which service we need
        switch outputService {
        case .pandoc(_):
            guard pandocWrapper != nil else {
                print("convertFile: pandoc not available")
                showError("Pandoc is not available")
                return
            }
        case .imagemagick(_):
            guard imageMagickWrapper != nil else {
                print("convertFile: ImageMagick not available")
                showError("ImageMagick is not available")
                return
            }
        case .ffmpeg(_):
            guard ffmpegWrapper != nil else {
                print("convertFile: FFmpeg not available")
                showError("FFmpeg is not available")
                return
            }
        }
        
        let serviceDescription = getServiceDescription(outputService)
        print("Starting batch conversion of \(inputURLs.count) files to \(serviceDescription)")
        
        isConverting = true
        errorMessage = nil
        conversionProgress = (current: 0, total: inputURLs.count)
        
        for (index, inputURL) in inputURLs.enumerated() {
            // Check for cancellation
            if Task.isCancelled {
                print("Conversion cancelled")
                return
            }
            
            // Mark this file as converting
            if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                files[fileIndex] = .converting(inputURL, fileName: inputURL.lastPathComponent)
            }
            conversionProgress.current = index + 1
            currentConversionFile = inputURL.lastPathComponent
            do {
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(outputService.fileExtension)
                
                print("Converting \(inputURL.lastPathComponent) to temporary file: \(tempURL.path)")
                
                switch outputService {
                case .pandoc(let format):
                    try await pandocWrapper!.convertFile(
                        inputURL: inputURL,
                        outputURL: tempURL,
                        to: format
                    )
                    
                    // Single file output for Pandoc
                    let data = try Data(contentsOf: tempURL)
                    let baseName = inputURL.deletingPathExtension().lastPathComponent
                    let fileName = "\(baseName).\(outputService.fileExtension)"
                    
                    let convertedFile = ConvertedFile(
                        originalURL: inputURL,
                        data: data,
                        fileName: fileName
                    )
                    
                    // Replace the converting file with the converted file
                    if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                        files[fileIndex] = .converted(convertedFile)
                    }
                    
                    try FileManager.default.removeItem(at: tempURL)
                    
                case .imagemagick(let format):
                    try await imageMagickWrapper!.convertImage(
                        inputURL: inputURL,
                        outputURL: tempURL,
                        to: format,
                        quality: useLossyCompression ? Int(imageQuality) : 100,
                        dpi: pdfToDpi
                    )
                    
                case .ffmpeg(let format):
                    try await ffmpegWrapper!.convertFile(
                        inputURL: inputURL,
                        outputURL: tempURL,
                        format: format,
                        quality: .medium,
                        audioOptions: format.isVideo ? nil : audioOptions
                    )
                    
                    // Single file output for FFmpeg
                    let data = try Data(contentsOf: tempURL)
                    let baseName = inputURL.deletingPathExtension().lastPathComponent
                    let fileName = "\(baseName).\(outputService.fileExtension)"
                    
                    let convertedFile = ConvertedFile(
                        originalURL: inputURL,
                        data: data,
                        fileName: fileName
                    )
                    
                    // Replace the converting file with the converted file
                    if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                        files[fileIndex] = .converted(convertedFile)
                    }
                    
                    try FileManager.default.removeItem(at: tempURL)
                }
                
                // ImageMagick-specific handling
                if case .imagemagick = outputService {
                    // Strip EXIF metadata if requested (preserving orientation)
                    // Only strip EXIF from formats that support it
                    if removeExifMetadata {
                        if let inputFormat = ImageFormat.detectFormat(from: inputURL),
                           inputFormat.supportsExifMetadata {
                            try ImageProcessor.shared.strip(exifMetadataExceptOrientation: tempURL)
                        }
                    }
                    
                    // For PDF input, ImageMagick might create multiple files
                    if let inputFormat = ImageFormat.detectFormat(from: inputURL),
                       inputFormat.requiresDpiConfiguration {
                        let baseName = inputURL.deletingPathExtension().lastPathComponent
                        let tempDir = tempURL.deletingLastPathComponent()
                        let baseTempName = tempURL.deletingPathExtension().lastPathComponent
                        let ext = tempURL.pathExtension
                        
                        
                        
                        var pageIndex = 0
                        
                        // Based on the debug output, ImageMagick uses: filename-N.ext
                        var pageFiles: [ConvertedFile] = []
                        while true {
                            let testFileName = "\(baseTempName)-\(pageIndex).\(ext)"
                            let testURL = tempDir.appendingPathComponent(testFileName)
                            
                            if FileManager.default.fileExists(atPath: testURL.path) {
                                let data = try Data(contentsOf: testURL)
                                let fileName = "\(baseName)-page\(pageIndex + 1).\(outputService.fileExtension)"
                                
                                let convertedFile = ConvertedFile(
                                    originalURL: inputURL,
                                    data: data,
                                    fileName: fileName
                                )
                                pageFiles.append(convertedFile)
                                
                                try FileManager.default.removeItem(at: testURL)
                                pageIndex += 1
                            } else {
                                break
                            }
                        }
                        
                        // Replace the converting file with converted files
                        print("PDF conversion found \(pageFiles.count) page files")
                        if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                            if pageFiles.isEmpty {
                                // If no numbered files were found, check for the original filename
                                if FileManager.default.fileExists(atPath: tempURL.path) {
                                    print("PDF conversion: Using fallback single file approach")
                                    let data = try Data(contentsOf: tempURL)
                                    let fileName = "\(baseName).\(outputService.fileExtension)"
                                    
                                    let convertedFile = ConvertedFile(
                                        originalURL: inputURL,
                                        data: data,
                                        fileName: fileName
                                    )
                                    
                                    // Replace the converting file with the converted file
                                    files[fileIndex] = .converted(convertedFile)
                                    print("Files array now has \(files.count) items after fallback")
                                    
                                    try FileManager.default.removeItem(at: tempURL)
                                }
                            } else {
                                // Remove the converting file and insert all page files
                                files.remove(at: fileIndex)
                                for (i, convertedFile) in pageFiles.enumerated() {
                                    files.insert(.converted(convertedFile), at: fileIndex + i)
                                }
                                print("Files array now has \(files.count) items")
                            }
                        }
                    } else {
                        // Single file output for non-PDF images
                        let data = try Data(contentsOf: tempURL)
                        let baseName = inputURL.deletingPathExtension().lastPathComponent
                        let fileName = "\(baseName).\(outputService.fileExtension)"
                        
                        let convertedFile = ConvertedFile(
                            originalURL: inputURL,
                            data: data,
                            fileName: fileName
                        )
                        
                        // Replace the converting file with the converted file
                        if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                            files[fileIndex] = .converted(convertedFile)
                        }
                        
                        try FileManager.default.removeItem(at: tempURL)
                    }
                }
                
                print("Successfully converted \(inputURL.lastPathComponent)")
            } catch {
                // Handle cancellation errors differently
                if error is CancellationError {
                    print("Conversion cancelled for \(inputURL.lastPathComponent)")
                    return
                }
                
                print("Conversion failed for \(inputURL.lastPathComponent): \(error)")
                
                // Mark this file as error
                if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                    files[fileIndex] = .error(inputURL, errorMessage: error.localizedDescription)
                }
                
                // Play failure sound only on first error
                if !hasPlayedFailureSound {
                    failureSound?.play()
                    hasPlayedFailureSound = true
                }
                
                // Continue to next file instead of stopping entire conversion
                continue
            }
        }
        
        // Check if there are no files currently converting (completion of current batch)
        let convertingCount = files.filter { 
            if case .converting = $0 { return true }
            return false
        }.count
        
        if convertingCount == 0 && !files.isEmpty {
            print("All files converted successfully!")
            // Play completion sound
            completionSound?.play()
        }
        
        isConverting = false
        currentConversionFile = ""
        conversionProgress = (current: 0, total: 0)
        conversionTask = nil
    }
    
    private func saveFile(data: Data, fileName: String, originalURL: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = [UTType(filenameExtension: outputService.fileExtension)!]
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                
                // Add to conversion history
                let inputFormat = originalURL.pathExtension.uppercased()
                let outputFormat = url.pathExtension.uppercased()
                savedHistoryManager.addConversion(
                    inputFileName: originalURL.lastPathComponent,
                    inputFormat: inputFormat,
                    outputFormat: outputFormat,
                    outputFileURL: url
                )
            } catch {
                showError(error.localizedDescription)
            }
        }
    }
    
    private func saveAllFiles() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            let convertedFilesList = files.compactMap { file in
                if case .converted(let convertedFile) = file {
                    return convertedFile
                } else {
                    return nil
                }
            }
            
            for file in convertedFilesList {
                let fileURL = folderURL.appendingPathComponent(file.fileName)
                do {
                    try file.data.write(to: fileURL)
                    
                    // Add to conversion history
                    let inputFormat = file.originalURL.pathExtension.uppercased()
                    let outputFormat = fileURL.pathExtension.uppercased()
                    savedHistoryManager.addConversion(
                        inputFileName: file.originalURL.lastPathComponent,
                        inputFormat: inputFormat,
                        outputFormat: outputFormat,
                        outputFileURL: fileURL
                    )
                } catch {
                    showError("Failed to save \(file.fileName): \(error.localizedDescription)")
                    return
                }
            }
        }
    }
    
    private func isConversionServiceAvailable() -> Bool {
        switch outputService {
        case .pandoc(_):
            return pandocWrapper != nil
        case .imagemagick(_):
            return imageMagickWrapper != nil
        case .ffmpeg(_):
            return ffmpegWrapper != nil
        }
    }
    
    private func isSupportedFileType(_ url: URL) -> Bool {
        // Detect format of the file (document, image, or media)
        let documentFormat = PandocFormat.detectFormat(from: url)
        let imageFormat = ImageFormat.detectFormat(from: url)
        let mediaFormat = FFmpegFormat.detectFormat(from: url)
        
        return documentFormat != nil || imageFormat != nil || mediaFormat != nil
    }
    
    private func updateOutputService() {
        let compatibleServices = getCompatibleServices()
        
        // If current outputService is still compatible, keep it
        if compatibleServices.contains(where: { $0.0 == outputService }) {
            return
        }
        
        // Otherwise, select the first compatible option if available
        if let firstService = compatibleServices.first {
            outputService = firstService.0
        }
    }
    
    private func getCompatibleServices() -> [(ConversionService, String)] {
        let inputURLs = files.compactMap { $0.url }
        guard !inputURLs.isEmpty else {
            return []
        }
        
        // Detect if inputs are documents, images, or media files
        let documentFormats = inputURLs.compactMap { PandocFormat.detectFormat(from: $0) }
        let imageFormats = inputURLs.compactMap { ImageFormat.detectFormat(from: $0) }
        let mediaFormats = inputURLs.compactMap { FFmpegFormat.detectFormat(from: $0) }
        
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
            let compatibleMediaFormats = FFmpegFormat.allCases
            compatibleServices.append(contentsOf: compatibleMediaFormats.compactMap { format in
                guard let config = FormatRegistry.shared.config(for: format) else { return nil }
                return (.ffmpeg(format), config.displayName)
            })
        }
        
        return compatibleServices.sorted { $0.1 < $1.1 }
    }
    
    private func getServiceDescription(_ service: ConversionService) -> String {
        switch service {
        case .pandoc(let format):
            return format.rawValue
        case .imagemagick(let format):
            return format.rawValue
        case .ffmpeg(let format):
            return format.rawValue
        }
    }
    
    private var shouldShowDpiSelector: Bool {
        // Show DPI selector when converting from formats that require DPI configuration
        let inputURLs = files.compactMap { $0.url }
        let hasInputRequiringDpi = inputURLs.contains { url in
            guard let format = ImageFormat.detectFormat(from: url) else { return false }
            return format.requiresDpiConfiguration
        }
        let isImageOutput = if case .imagemagick(_) = outputService { true } else { false }
        return hasInputRequiringDpi && isImageOutput
    }
    
    private var shouldShowAudioOptions: Bool {
        // Show audio options when:
        // 1. We're converting to an audio format with FFmpeg
        if case .ffmpeg(let format) = outputService {
            return !format.isVideo
        }
        return false
    }
    
    private var shouldShowExifOption: Bool {
        // Show EXIF metadata option only when:
        // 1. We're converting to an image format that supports EXIF metadata
        if case .imagemagick(let outputFormat) = outputService {
            return outputFormat.supportsExifMetadata
        }
        return false
    }
    
    private var currentFFmpegFormat: FFmpegFormat? {
        if case .ffmpeg(let format) = outputService {
            return format
        }
        return nil
    }
    
    private var pdfToDpiIndex: Int {
        switch pdfToDpi {
        case 72: return 0
        case 150: return 1
        case 300: return 2
        case 600: return 3
        case 1200: return 4
        case 2400: return 5
        default: return 1
        }
    }
    
    
    private func iconForFile(fileState: FileState) -> NSImage {
        switch fileState {
        case .input(let url), .converting(let url, _), .error(let url, _):
            return NSWorkspace.shared.icon(forFile: url.path)
        case .converted(let file):
            return iconForFile(fileName: file.fileName)
        }
    }
    
    private func iconForFile(fileName: String) -> NSImage {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            FileManager.default.createFile(atPath: tempURL.path, contents: Data(), attributes: nil)
        }
        let icon = NSWorkspace.shared.icon(forFile: tempURL.path)
        try? FileManager.default.removeItem(at: tempURL)
        return icon
    }
    
    @ViewBuilder
    private func fileRow(for fileState: FileState) -> some View {
        switch fileState {
        case .input(let url):
            FileRow(
                url: url,
                onRemove: {
                    files.removeAll { $0.id == fileState.id }
                }
            )
        case .converting(let url, let fileName):
            ConvertingFileRow(url: url, fileName: fileName)
        case .converted(let convertedFile):
            ConvertedFileContentRow(
                file: convertedFile,
                onSave: {
                    saveFile(data: convertedFile.data, fileName: convertedFile.fileName, originalURL: convertedFile.originalURL)
                }
            )
        case .error(let url, let message):
            ErrorFileRow(
                url: url, 
                fileName: fileState.fileName, 
                message: message,
                onRemove: {
                    files.removeAll { $0.id == fileState.id }
                }
            )
        }
    }
}

extension PandocFormat {
    var fileExtension: String {
        switch self {
        // Common formats
        case .markdown, .commonmark, .gfm, .markdownStrict, .markdownPhpextra, .markdownMmd:
            return "md"
        case .html, .html4, .html5, .chunkedhtml:
            return "html"
        case .latex: return "tex"
        case .pdf: return "pdf"
        case .docx: return "docx"
        case .rtf: return "rtf"
        case .epub, .epub2, .epub3: return "epub"
        case .plain: return "txt"
        
        // Lightweight markup
        case .rst: return "rst"
        case .asciidoc: return "adoc"
        case .textile: return "textile"
        case .org: return "org"
        case .muse: return "muse"
        case .creole: return "creole"
        case .djot: return "djot"
        case .markua: return "markua"
        case .txt2tags: return "t2t"
        
        // Wiki formats
        case .mediawiki, .dokuwiki, .tikiwiki, .twiki, .vimwiki, .xwiki, .zimwiki, .jira:
            return "wiki"
        
        // Documentation formats
        case .man: return "man"
        case .ms: return "ms"
        case .mdoc: return "mdoc"
        case .texinfo: return "texi"
        case .haddock: return "haddock"
        
        // XML formats
        case .docbook, .docbook4, .docbook5: return "xml"
        case .jats, .jatsArchiving, .jatsPublishing, .jatsArticleauthoring: return "xml"
        case .bits: return "xml"
        case .tei: return "xml"
        case .opml: return "opml"
        case .opendocument: return "xml"
        
        // Office formats
        case .odt: return "odt"
        case .powerpoint: return "pptx"
        case .openoffice: return "odf"
        
        // Academic formats
        case .context: return "tex"
        case .biblatex, .bibtex: return "bib"
        case .csljson: return "json"
        case .ris: return "ris"
        case .endnotexml: return "xml"
        
        // Presentation formats
        case .beamer: return "tex"
        case .slidy, .slideous, .dzslides, .revealjs, .s5: return "html"
        
        // Other formats
        case .json: return "json"
        case .native: return "native"
        case .icml: return "icml"
        case .typst: return "typ"
        case .ipynb: return "ipynb"
        case .csv: return "csv"
        case .tsv: return "tsv"
        case .ansi: return "ansi"
        case .fb2: return "fb2"
        }
    }
}


#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: ConversionRecord.self, configurations: config)
    let context = container.mainContext
    let manager = SavedHistoryManager(modelContext: context)
    
    ConverterView(savedHistoryManager: manager)
        .modelContainer(container)
}
