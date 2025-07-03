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
    let fileSelectionController: FileSelectionController
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
    @AppStorage("useNativePDFConversion") private var useNativePDFConversion: Bool = false
    @AppStorage("pdfNativeScale") private var pdfNativeScale: Double = 2.0
    @AppStorage("pdfNativeAddBackground") private var pdfNativeAddBackground: Bool = true
    @State private var audioOptions = AudioOptions()
    @State private var videoOptions = VideoOptions()
    @State private var archiveOptions = ArchiveOptions()

    @State private var pandocWrapper: PandocWrapper?
    @State private var pandocInitError: String?
    @State private var imageMagickWrapper: ImageMagickWrapper?
    @State private var imageMagickInitError: String?
    @State private var ffmpegWrapper: FFmpegWrapper?
    @State private var ffmpegInitError: String?
    @State private var ocrService: OCRService?
    @State private var ttsWrapper: TextToSpeechWrapper?
    @State private var ttsInitError: String?
    @State private var conversionTask: Task<Void, Never>?
    @AppStorage("ocrUseLanguageCorrection") private var ocrUseLanguageCorrection: Bool = false
    @AppStorage("ocrSelectedLanguage") private var ocrSelectedLanguage: String = "automatic"
    @AppStorage("saveToSourceFolder") private var saveToSourceFolder: Bool = false
    @AppStorage("playSounds") private var playSounds: Bool = true
    @State private var ocrOptions = OCRService.Options()
    @State private var ttsOptions = TTSOptions()
    @State private var inputAudioBitDepth: Int?
    @State private var inputAudioSampleRate: Int?
    @State private var inputAudioChannels: Int?
    @State private var inputAudioBitRate: Int?
    private let audioPropertyDetector = AudioPropertyDetector()

    // MARK: - Computed Properties
    private var isConvertButtonDisabled: Bool {
        return files.isEmpty ||
               !isConversionServiceAvailable() ||
               files.contains(where: { if case .converting = $0 { true } else { false } }) ||
               !files.contains(where: { if case .input = $0 { true } else { false } })
    }

    private var isNativePDFImageConversion: Bool {
        guard case .imagemagick(let format) = outputService else { return false }
        return useNativePDFConversion &&
               (format == .png || format == .jpeg || format == .jpg || format == .tiff || format == .tif)
    }

    private func cleanupTempFiles() {
        for fileState in files {
            if case .converted(let convertedFile) = fileState {
                try? FileManager.default.removeItem(at: convertedFile.tempURL.deletingLastPathComponent())
            }
        }
    }

    private let completionSound: NSSound? = {
        guard let soundURL = Bundle.main.url(forResource: "completed", withExtension: "wav") else {
            return nil
        }
        return NSSound(contentsOf: soundURL, byReference: true)
    }()

    private let failureSound: NSSound? = {
        guard let soundURL = Bundle.main.url(forResource: "error", withExtension: "wav") else {
            return nil
        }
        return NSSound(contentsOf: soundURL, byReference: true)
    }()

    // Computed property to check if we're in PDF merge mode
    private var isPDFMergeMode: Bool {
        guard case .imagemagick(.pdf) = outputService else { return false }
        let inputURLs = files.compactMap { fileState in
            if case .input(let url) = fileState {
                return url
            }
            return nil
        }
        let allPDFs = inputURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
        return allPDFs && inputURLs.count > 1
    }

    // Function to move files up or down in the array
    private func moveFile(at index: Int, direction: Int) {
        let newIndex = index + direction
        guard newIndex >= 0 && newIndex < files.count else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            files.swapAt(index, newIndex)
        }
    }

    // Function to clear converted files
    private func clearConvertedFiles() {
        // First, clean up temp files for converted files
        for fileState in files {
            if case .converted(let convertedFile) = fileState {
                try? FileManager.default.removeItem(at: convertedFile.tempURL.deletingLastPathComponent())
            }
        }

        // Remove all converted files from the array
        withAnimation(.easeInOut(duration: 0.2)) {
            files.removeAll { fileState in
                if case .converted = fileState {
                    return true
                }
                return false
            }
        }
    }

    // Function to reset all files back to input state
    private func resetFilesToInput() {
        // Clean up temp files for converted files
        for fileState in files {
            if case .converted(let convertedFile) = fileState {
                try? FileManager.default.removeItem(at: convertedFile.tempURL.deletingLastPathComponent())
            }
        }

        // Process files, keeping converting files as-is
        var newFiles: [FileState] = []
        var seenURLs = Set<URL>()

        for fileState in files {
            switch fileState {
            case .converting:
                // Keep files that are currently converting
                newFiles.append(fileState)
            case .input(let url):
                // Keep input files if not seen before
                if !seenURLs.contains(url) {
                    seenURLs.insert(url)
                    newFiles.append(fileState)
                }
            case .converted(let convertedFile):
                // Reset converted files to input state if not seen before
                let originalURL = convertedFile.originalURL
                if !seenURLs.contains(originalURL) {
                    seenURLs.insert(originalURL)
                    newFiles.append(.input(originalURL))
                }
            case .error(let url, _):
                // Reset error files to input state if not seen before
                if !seenURLs.contains(url) {
                    seenURLs.insert(url)
                    newFiles.append(.input(url))
                }
            }
        }

        // Update files array
        withAnimation(.easeInOut(duration: 0.2)) {
            files = newFiles
            errorMessage = nil
        }
    }

    // MARK: - File pane
    var body: some View {
        HStack(spacing: 0) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(
                                    isTargeted ? Color.accentColor : Color.gray.opacity(0.3),
                                    style: StrokeStyle(lineWidth: isTargeted ? 2.5 : 2, dash: [8, 8])
                                )
                                .animation(.easeInOut(duration: 0.2), value: isTargeted)
                        )
                        .shadow(
                            color: isTargeted ? Color.accentColor.opacity(0.4) : Color.clear,
                            radius: isTargeted ? 12 : 0
                        )
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
                                            FilePreviewView(url: convertedFile.tempURL)
                                        case .error(let url, _):
                                            FilePreviewView(url: url)
                                        }

                                        if case .converting = fileState {
                                            Rectangle()
                                                .fill(Color.black.opacity(0.6))
                                                .overlay(
                                                    ActivityIndicatorView(
                                                        isVisible: .constant(true),
                                                        type: .scalingDots(count: 3, inset: 4)
                                                    )
                                                        .frame(width: 40, height: 20)
                                                        .foregroundStyle(.white)
                                                )
                                        }
                                    }

                                    Text(fileState.fileName)
                                        .font(.headline)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
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
                                                resetFilesToInput()
                                            }

                                            if let url = fileState.url {
                                                PreviewButton(action: {
                                                    QuickLookManager.shared.previewFile(at: url)
                                                })
                                                FinderButton(action: {
                                                    NSWorkspace.shared.selectFile(
                                                        url.path,
                                                        inFileViewerRootedAtPath: ""
                                                    )
                                                })
                                            }
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 8)
                                    }
                                } else {
                                    FileToolbar(
                                        files: $files,
                                        onReset: resetFilesToInput,
                                        onClearConverted: clearConvertedFiles,
                                        onSaveAll: saveAllFiles,
                                        onSave: saveFile,
                                        onUpdateOutputService: updateOutputService,
                                        onClear: {
                                            files = []
                                            errorMessage = nil
                                        }
                                    )
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

                                FileToolbar(
                                    files: $files,
                                    onReset: resetFilesToInput,
                                    onClearConverted: clearConvertedFiles,
                                    onSaveAll: saveAllFiles,
                                    onSave: saveFile,
                                    onUpdateOutputService: updateOutputService,
                                    onClear: {
                                        files = []
                                        errorMessage = nil
                                    }
                                )
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image("chameleon.glyph")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 128, height: 128)
                                .foregroundStyle(Color.secondary.opacity(0.4))
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
                FormatPicker(selectedService: $outputService, inputFileURLs: files.compactMap { $0.url }, isPandocAvailable: pandocWrapper != nil)
                    .padding(.top)
                    .disabled(files.isEmpty ||
                              files.contains(where: { if case .converting = $0 { true } else { false } }))

                // Show image conversion options
                if case .imagemagick(let format) = outputService, !files.isEmpty {
                    // Check if we're combining PDFs (multiple PDF inputs to PDF output)
                    let inputURLs = files.compactMap { fileState in
                        if case .input(let url) = fileState {
                            return url
                        }
                        return nil
                    }
                    let allPDFs = inputURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
                    let isCombiningPDFs = allPDFs && inputURLs.count > 1 && format == .pdf

                    Form {
                        // Show PDF-specific options when converting PDF to image (but not when combining PDFs)
                        if !isCombiningPDFs && files.contains(where: { fileState in
                            guard let url = fileState.url,
                                  let inputFormat = ImageFormat.detectFormat(from: url) else { return false }
                            return inputFormat.requiresDpiConfiguration
                        }) {
                            // Only show native PDF option for formats that PDFKit supports
                            if format == .png || format == .jpeg || format == .jpg ||
                               format == .tiff || format == .tif {
                                VStack(alignment: .leading, spacing: 4) {
                                    Picker("Engine", selection: $useNativePDFConversion) {
                                        Text("ImageMagick").tag(false)
                                        Text("Native").tag(true)
                                    }
                                    .pickerStyle(.segmented)
                                    .help("Choose between ImageMagick or native")
                                }
                                .padding(.bottom, 8)
                            }

                            if isNativePDFImageConversion {
                                HStack {
                                    Text("PDF Scale")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(pdfNativeScale, specifier: "%.1f")x")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }

                                Slider(
                                    value: $pdfNativeScale,
                                    in: 0.5...4.0,
                                    step: 0.5
                                )
                                .labelsHidden()
                                .help("Scale factor for PDF rendering")

                                // Only show background toggle for formats that support transparency
                                if format == .png || format == .tiff || format == .tif {
                                    Toggle("Add white background", isOn: $pdfNativeAddBackground)
                                        .help("Add a white background to transparent areas of the PDF")
                                }
                            } else {
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

                                Slider(
                                    value: Binding(
                                        get: {
                                            let dpiValues = [72, 150, 300, 600, 1_200, 2_400]
                                            return Double(dpiValues.firstIndex(of: pdfToDpi) ?? 1)
                                        },
                                        set: { newValue in
                                            let dpiValues = [72, 150, 300, 600, 1_200, 2_400]
                                            let index = Int(newValue)
                                            pdfToDpi = dpiValues[min(max(0, index), dpiValues.count - 1)]
                                        }
                                    ),
                                    in: 0...5,
                                    step: 1
                                )
                                .labelsHidden()
                            }
                        }

                        // Show EXIF metadata removal toggle for image conversions (but not when combining PDFs)
                        if !isCombiningPDFs && format.supportsExifMetadata {
                            Toggle("Strip EXIF Metadata", isOn: $removeExifMetadata)
                        }

                        // Show quality controls for lossy image conversions (but not when combining PDFs)
                        if !isCombiningPDFs && format.isLossy {
                            Group {
                                Toggle("Lossy Compression", isOn: $useLossyCompression)

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

                                Slider(
                                    value: $imageQuality,
                                    in: 1...100,
                                    minimumValueLabel: Text("1").font(.caption2),
                                    maximumValueLabel: Text("100").font(.caption2),
                                    label: {
                                        Text("Image Quality")
                                    }
                                )
                                .labelsHidden()
                                .disabled(!useLossyCompression)
                            }
                        }
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: outputService)
                }

                // Show audio options for FFmpeg audio conversions
                if shouldShowAudioOptions {
                    AudioOptionsView(
                        audioOptions: $audioOptions,
                        outputFormat: currentFFmpegFormat,
                        inputFormat: inputFFmpegFormat,
                        inputSampleRate: inputAudioSampleRate,
                        inputChannels: inputAudioChannels,
                        inputBitDepth: inputAudioBitDepth,
                        inputBitRate: inputAudioBitRate
                    )
                        .onChange(of: outputService) { _, _ in
                            // Update sample size when output format changes to lossless
                            if case .ffmpeg(let outputFormat) = outputService,
                               let config = FormatRegistry.shared.config(for: outputFormat),
                               config.isLossless,
                               let bitDepth = inputAudioBitDepth {
                                updateSampleSizeForBitDepth(bitDepth)
                            }
                        }
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.2), value: outputService)
                }

                // Show video options for FFmpeg video conversions
                if shouldShowVideoOptions {
                    VideoOptionsView(videoOptions: $videoOptions, outputFormat: currentFFmpegFormat)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.2), value: outputService)
                }

                // Show OCR options
                if shouldShowOCROptions {
                    OCROptionsView(
                        ocrOptions: $ocrOptions,
                        ocrUseLanguageCorrection: $ocrUseLanguageCorrection,
                        ocrSelectedLanguage: $ocrSelectedLanguage
                    )
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: outputService)
                }

                // Show TTS options
                if shouldShowTTSOptions {
                    TTSOptionsView(
                        ttsOptions: $ttsOptions,
                        ttsWrapper: ttsWrapper
                    )
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: outputService)
                }

                // Show archive options
                if shouldShowArchiveOptions {
                    let inputFileCount = files.compactMap { fileState in
                        if case .input(let url) = fileState {
                            return url
                        }
                        return nil
                    }.count

                    ArchiveOptionsView(archiveOptions: $archiveOptions, fileCount: inputFileCount)
                        .padding(.top, 8)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.2), value: outputService)
                }

                Spacer()

                VStack {
                    if isConverting {
                        Button(action: {
                            cancelConversion()
                        }, label: {
                            Text("Cancel")
                                .font(.title3)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        })
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.bottom)
                    } else {
                        Button(action: {
                            print("Convert button clicked")
                            conversionTask = Task {
                                await convertFile()
                            }
                        }, label: {
                            Label("Convert", systemImage: "arrowshape.zigzag.right")
                                .font(.title3)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                        })
                        .buttonStyle(.bordered)
                        .disabled(isConvertButtonDisabled)
                        .controlSize(.large)
                        .padding(.bottom)
                    }
                }
            }
            .padding()
            .frame(width: 320)

        }
        .onAppear {
            initializePandoc()
            initializeImageMagick()
            initializeFFmpeg()
            initializeOCR()
            initializeTTS()
            fileSelectionController.selectFileAction = selectFile
        }
        .onDisappear {
            cleanupTempFiles()
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
        ocrService?.cancel()
        ttsWrapper?.cancel()

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

    private func initializeOCR() {
        print("Initializing OCR Service...")
        ocrService = OCRService()
        // Initialize OCR options with saved preferences
        ocrOptions.usesLanguageCorrection = ocrUseLanguageCorrection
        ocrOptions.recognitionLanguages = [ocrSelectedLanguage]
        print("OCR Service initialized successfully")
    }

    private func initializeTTS() {
        do {
            ttsWrapper = try TextToSpeechWrapper()
            ttsInitError = nil
        } catch {
            ttsWrapper = nil
            ttsInitError = error.localizedDescription
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { urlData, _ in
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
                            self.detectInputAudioBitDepth()
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
                            self.detectInputAudioBitDepth()
                        } else {
                            // Replace existing files with the new incompatible file
                            self.files = [.input(url)]
                            self.errorMessage = nil
                            self.updateOutputService()
                            self.detectInputAudioBitDepth()
                        }
                    }
                }
            }
        }

        return true
    }

    private func utType(for extension: String) -> UTType? {
        return UTType(filenameExtension: `extension`)
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        
        var allowedTypes: [UTType] = [
            // Document types
            .text, .plainText, .sourceCode, .html,
            // Image types
            .image, .jpeg, .png, .gif, .bmp, .tiff, .pdf
        ]
        
        // Add custom file types safely
        let customExtensions = ["md", "tex", "rst", "org", "docx", "odt", "epub", "webp", "heic", "heif", "svg", "ico"]
        for ext in customExtensions {
            if let type = utType(for: ext) {
                allowedTypes.append(type)
            }
        }
        
        panel.allowedContentTypes = allowedTypes

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
                    detectInputAudioBitDepth()
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
                    detectInputAudioBitDepth()
                } else {
                    // Replace existing files with the new incompatible file
                    cleanupTempFiles()
                    files = [.input(url)]
                    errorMessage = nil
                    updateOutputService()
                    detectInputAudioBitDepth()
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
            switch fileState {
            case .input(let url), .error(let url, _):
                return url
            case .converted, .converting:
                return nil // Only process actual input files
            }
        }
        guard !inputURLs.isEmpty else {
            print("convertFile: no input files")
            return
        }

        // Track if we've played the failure sound
        var hasPlayedFailureSound = false

        // Check which service we need
        switch outputService {
        case .pandoc:
            guard pandocWrapper != nil else {
                print("convertFile: pandoc not available")
                showError("Pandoc is not available")
                return
            }
        case .imagemagick:
            guard imageMagickWrapper != nil else {
                print("convertFile: ImageMagick not available")
                showError("ImageMagick is not available")
                return
            }
        case .ffmpeg:
            guard ffmpegWrapper != nil else {
                print("convertFile: FFmpeg not available")
                showError("FFmpeg is not available")
                return
            }
        case .ocr:
            guard ocrService != nil else {
                print("convertFile: OCR not available")
                showError("OCR is not available")
                return
            }
        case .tts:
            guard ttsWrapper != nil else {
                showError("Text-to-Speech is not available")
                return
            }
        case .archive:
            // Archive service doesn't require external tools
            break
        }

        // Check if we're creating an archive
        if case .archive(let format) = outputService {
            // Special handling for creating archives
            print("Creating \(format.displayName) with \(inputURLs.count) files")

            isConverting = true
            errorMessage = nil
            conversionProgress = (current: 1, total: 1)
            currentConversionFile = "Creating archive..."

            // Mark all files as converting
            for url in inputURLs {
                if let fileIndex = files.firstIndex(where: { $0.url == url }) {
                    files[fileIndex] = .converting(url, fileName: url.lastPathComponent)
                }
            }

            do {
                // Check for cancellation
                if Task.isCancelled {
                    print("Archive creation cancelled")
                    return
                }

                let archiveService = ArchiveService()
                let createdArchives: [URL]

                if archiveOptions.archiveSeparately {
                    // Create separate archives for each file
                    let tempDirectory = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

                    createdArchives = try await archiveService.createArchive(
                        format: format,
                        from: inputURLs,
                        outputURL: tempDirectory.appendingPathComponent("placeholder"),
                        // Will be ignored for separate archiving
                        separately: true,
                        verifyAfterCreation: archiveOptions.verifyAfterCreation,
                        compressionLevel: archiveOptions.compressionLevel
                    )
                } else {
                    // Create single archive containing all files
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(format.fileExtension)

                    createdArchives = try await archiveService.createArchive(
                        format: format,
                        from: inputURLs,
                        outputURL: tempURL,
                        separately: false,
                        verifyAfterCreation: archiveOptions.verifyAfterCreation,
                        compressionLevel: archiveOptions.compressionLevel
                    )
                }

                // Create ConvertedFile objects for each created archive
                var convertedFiles: [ConvertedFile] = []

                for (index, archiveURL) in createdArchives.enumerated() {
                    let fileName = archiveURL.lastPathComponent
                    let originalURL = archiveOptions.archiveSeparately && index < inputURLs.count ?
                        inputURLs[index] : inputURLs[0]

                    // Move to final temp location with proper filename
                    let finalTempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathComponent(fileName)
                    try FileManager.default.createDirectory(at: finalTempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.moveItem(at: archiveURL, to: finalTempURL)

                    let convertedFile = ConvertedFile(
                        originalURL: originalURL,
                        tempURL: finalTempURL,
                        fileName: fileName
                    )
                    convertedFiles.append(convertedFile)
                }

                // Remove all converting files and add the archive results
                files.removeAll { fileState in
                    if case .converting = fileState {
                        return true
                    }
                    return false
                }

                for convertedFile in convertedFiles {
                    files.append(.converted(convertedFile))
                }

                print("Successfully created archive")

                // Play completion sound
                if playSounds {
                    completionSound?.play()
                }

                isConverting = false
                currentConversionFile = ""
                conversionProgress = (current: 0, total: 0)
                conversionTask = nil

                return // Exit early, we're done
            } catch {
                // Handle cancellation errors differently
                if error is CancellationError {
                    print("Archive creation cancelled")
                    return
                }

                print("Archive creation failed: \(error)")

                // Mark all files as error
                for url in inputURLs {
                    if let fileIndex = files.firstIndex(where: { $0.url == url }) {
                        files[fileIndex] = .error(url, errorMessage: error.localizedDescription)
                    }
                }

                // Play failure sound
                if playSounds {
                    failureSound?.play()
                }

                isConverting = false
                currentConversionFile = ""
                conversionProgress = (current: 0, total: 0)
                conversionTask = nil

                return
            }
        }

        // Check if we're combining multiple PDFs
        let allPDFs = inputURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
        if case .imagemagick(.pdf) = outputService, allPDFs, inputURLs.count > 1 {
            // Special handling for merging PDFs
            print("Merging \(inputURLs.count) PDFs into one")

            isConverting = true
            errorMessage = nil
            conversionProgress = (current: 1, total: 1)
            currentConversionFile = "Merging PDFs..."

            // Mark all files as converting
            for url in inputURLs {
                if let fileIndex = files.firstIndex(where: { $0.url == url }) {
                    files[fileIndex] = .converting(url, fileName: url.lastPathComponent)
                }
            }

            do {
                // Check for cancellation
                if Task.isCancelled {
                    print("PDF combination cancelled")
                    return
                }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("pdf")

                // Combine all PDFs
                try await PDFKitService.combinePDFs(at: inputURLs, outputURL: tempURL)

                // Create output filename
                let fileName = inputURLs.count == 2 ?
                    "\(inputURLs[0].deletingPathExtension().lastPathComponent)_\(inputURLs[1].deletingPathExtension().lastPathComponent)_combined.pdf" :
                    "combined_\(inputURLs.count)_pdfs.pdf"

                // Move to final temp location with proper filename
                let finalTempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathComponent(fileName)
                try FileManager.default.createDirectory(at: finalTempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: tempURL, to: finalTempURL)

                let convertedFile = ConvertedFile(
                    originalURL: inputURLs[0], // Use first file as original
                    tempURL: finalTempURL,
                    fileName: fileName
                )

                // Remove all converting files and add the single combined result
                files.removeAll { fileState in
                    if case .converting = fileState {
                        return true
                    }
                    return false
                }
                files.append(.converted(convertedFile))

                print("Successfully combined PDFs")

                // Play completion sound
                if playSounds {
                    if playSounds {
                completionSound?.play()
            }
                }

                isConverting = false
                currentConversionFile = ""
                conversionProgress = (current: 0, total: 0)
                conversionTask = nil

                return // Exit early, we're done
            } catch {
                // Handle cancellation errors differently
                if error is CancellationError {
                    print("PDF combination cancelled")
                    return
                }

                print("PDF combination failed: \(error)")

                // Mark all files as error
                for url in inputURLs {
                    if let fileIndex = files.firstIndex(where: { $0.url == url }) {
                        files[fileIndex] = .error(url, errorMessage: error.localizedDescription)
                    }
                }

                // Play failure sound
                if playSounds {
                    failureSound?.play()
                }

                isConverting = false
                currentConversionFile = ""
                conversionProgress = (current: 0, total: 0)
                conversionTask = nil

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
                    let baseName = inputURL.deletingPathExtension().lastPathComponent
                    let fileName = "\(baseName).\(outputService.fileExtension)"

                    // Move temp file to a more permanent temp location with proper filename
                    let finalTempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathComponent(fileName)
                    try FileManager.default.createDirectory(at: finalTempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.moveItem(at: tempURL, to: finalTempURL)

                    let convertedFile = ConvertedFile(
                        originalURL: inputURL,
                        tempURL: finalTempURL,
                        fileName: fileName
                    )

                    // Replace the converting file with the converted file
                    if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                        files[fileIndex] = .converted(convertedFile)
                    }

                case .imagemagick(let format):
                    // Check if we should use native PDF conversion
                    if useNativePDFConversion && inputURL.pathExtension.lowercased() == "pdf" {
                        // Use PDFKit for PDF to image conversion
                        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                        // JPEG always needs a background since it doesn't support transparency
                        let backgroundColor: NSColor = (format == .jpeg || format == .jpg) ? .white :
                                                      (pdfNativeAddBackground ? .white : .clear)

                        let options = PDFKitService.PDFConversionOptions(
                            scale: CGFloat(pdfNativeScale),
                            format: mapImageFormatToPDFKitFormat(format),
                            backgroundColor: backgroundColor,
                            jpegQuality: CGFloat(imageQuality) / 100.0
                        )

                        let outputURLs = try await PDFKitService.convertPDFToImages(
                            at: inputURL,
                            outputDirectory: tempDir,
                            options: options
                        )

                        // PDFKit handles multi-page PDFs directly, no need for the complex file detection
                        // Skip to the end of the ImageMagick-specific handling

                        // Handle the converted files
                        if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                            if outputURLs.count == 1 {
                                // Single page PDF
                                let baseName = inputURL.deletingPathExtension().lastPathComponent
                                let fileName = "\(baseName).\(format.fileExtension)"

                                // Move to final temp location with proper filename
                                let finalTempURL = FileManager.default.temporaryDirectory
                                    .appendingPathComponent(UUID().uuidString)
                                    .appendingPathComponent(fileName)
                                try FileManager.default.createDirectory(
                                    at: finalTempURL.deletingLastPathComponent(),
                                    withIntermediateDirectories: true
                                )
                                try FileManager.default.moveItem(at: outputURLs[0], to: finalTempURL)

                                let convertedFile = ConvertedFile(
                                    originalURL: inputURL,
                                    tempURL: finalTempURL,
                                    fileName: fileName
                                )
                                files[fileIndex] = .converted(convertedFile)

                                // Clean up the temp directory
                                try FileManager.default.removeItem(at: tempDir)
                            } else {
                                // Multi-page PDF - keep files in their directory
                                files.remove(at: fileIndex)
                                for (i, outputURL) in outputURLs.enumerated() {
                                    let convertedFile = ConvertedFile(
                                        originalURL: inputURL,
                                        tempURL: outputURL,
                                        fileName: outputURL.lastPathComponent
                                    )
                                    files.insert(.converted(convertedFile), at: fileIndex + i)
                                }
                                // Don't remove tempDir for multi-page since we're using those URLs
                            }
                        }

                        // Skip the rest of ImageMagick handling for this file
                        continue
                    } else {
                        // Use ImageMagick for regular image conversion
                        try await imageMagickWrapper!.convertImage(
                            inputURL: inputURL,
                            outputURL: tempURL,
                            to: format,
                            quality: useLossyCompression ? Int(imageQuality) : 100,
                            dpi: pdfToDpi
                        )
                    }

                case .ffmpeg(let format):
                    try await ffmpegWrapper!.convertFile(
                        inputURL: inputURL,
                        outputURL: tempURL,
                        format: format,
                        quality: format.isVideo ? videoOptions.crfQuality : .medium,
                        audioOptions: format.isVideo ? nil : audioOptions,
                        videoOptions: format.isVideo ? videoOptions : nil
                    )

                    // Single file output for FFmpeg
                    let baseName = inputURL.deletingPathExtension().lastPathComponent
                    let fileName = "\(baseName).\(outputService.fileExtension)"

                    // Move temp file to a more permanent temp location with proper filename
                    let finalTempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathComponent(fileName)
                    try FileManager.default.createDirectory(at: finalTempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.moveItem(at: tempURL, to: finalTempURL)

                    let convertedFile = ConvertedFile(
                        originalURL: inputURL,
                        tempURL: finalTempURL,
                        fileName: fileName
                    )

                    // Replace the converting file with the converted file
                    if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                        files[fileIndex] = .converted(convertedFile)
                    }

                case .ocr(let format):
                    let recognizedText: String

                    switch format {
                    case .txt:
                        // Always use Vision OCR for the generic .txt format
                        if inputURL.pathExtension.lowercased() == "pdf" {
                            // Use Vision OCR on PDF pages
                            recognizedText = try await PDFTextExtractor.extractText(from: inputURL, method: .vision)
                        } else {
                            // Use Vision framework for OCR on images
                            recognizedText = try await ocrService!.recognizeText(
                                from: inputURL,
                                options: ocrOptions
                            )
                        }

                    case .txtExtract:
                        // Direct text extraction using PDFKit
                        recognizedText = try await PDFTextExtractor.extractText(from: inputURL, method: .pdfKit)

                    case .txtOCR:
                        // OCR using Vision framework
                        if inputURL.pathExtension.lowercased() == "pdf" {
                            // Use Vision OCR on PDF pages
                            recognizedText = try await PDFTextExtractor.extractText(from: inputURL, method: .vision)
                        } else {
                            // Use Vision framework for OCR on images
                            recognizedText = try await ocrService!.recognizeText(
                                from: inputURL,
                                options: ocrOptions
                            )
                        }
                    }

                    // Write text to temp file
                    let baseName = inputURL.deletingPathExtension().lastPathComponent
                    let fileName = "\(baseName).\(outputService.fileExtension)"

                    let finalTempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathComponent(fileName)
                    try FileManager.default.createDirectory(at: finalTempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try recognizedText.write(to: finalTempURL, atomically: true, encoding: .utf8)

                    let convertedFile = ConvertedFile(
                        originalURL: inputURL,
                        tempURL: finalTempURL,
                        fileName: fileName
                    )

                    // Replace the converting file with the converted file
                    if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                        files[fileIndex] = .converted(convertedFile)
                    }

                case .tts(let format):
                    // Convert text to speech
                    try await ttsWrapper!.convertTextToSpeech(
                        inputURL: inputURL,
                        outputURL: tempURL,
                        format: format,
                        voice: ttsOptions.selectedVoice,
                        rate: ttsOptions.speechRate
                    )

                    // Single file output for TTS
                    let baseName = inputURL.deletingPathExtension().lastPathComponent
                    let fileName = "\(baseName).\(outputService.fileExtension)"

                    // Move temp file to a more permanent temp location with proper filename
                    let finalTempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathComponent(fileName)
                    try FileManager.default.createDirectory(at: finalTempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try FileManager.default.moveItem(at: tempURL, to: finalTempURL)

                    let convertedFile = ConvertedFile(
                        originalURL: inputURL,
                        tempURL: finalTempURL,
                        fileName: fileName
                    )

                    // Replace the converting file with the converted file
                    if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                        files[fileIndex] = .converted(convertedFile)
                    }

                case .archive:
                    // Archive creation should have been handled earlier - this is an error
                    fatalError("Archive creation should not reach individual file conversion loop")
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
                            // Check for cancellation in the multi-page processing loop
                            if Task.isCancelled {
                                print("Multi-page PDF processing cancelled")
                                break
                            }

                            let testFileName = "\(baseTempName)-\(pageIndex).\(ext)"
                            let testURL = tempDir.appendingPathComponent(testFileName)

                            if FileManager.default.fileExists(atPath: testURL.path) {
                                let fileName = "\(baseName)-page\(pageIndex + 1).\(outputService.fileExtension)"

                                // Move to final location with proper filename
                                let finalTempURL = FileManager.default.temporaryDirectory
                                    .appendingPathComponent(UUID().uuidString)
                                    .appendingPathComponent(fileName)
                                try FileManager.default.createDirectory(
                                    at: finalTempURL.deletingLastPathComponent(),
                                    withIntermediateDirectories: true
                                )
                                try FileManager.default.moveItem(at: testURL, to: finalTempURL)

                                let convertedFile = ConvertedFile(
                                    originalURL: inputURL,
                                    tempURL: finalTempURL,
                                    fileName: fileName
                                )
                                pageFiles.append(convertedFile)

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
                                    let fileName = "\(baseName).\(outputService.fileExtension)"

                                    // Move to final location with proper filename
                                    let finalTempURL = FileManager.default.temporaryDirectory
                                        .appendingPathComponent(UUID().uuidString)
                                        .appendingPathComponent(fileName)
                                    try FileManager.default.createDirectory(
                                        at: finalTempURL.deletingLastPathComponent(),
                                        withIntermediateDirectories: true
                                    )
                                    try FileManager.default.moveItem(at: tempURL, to: finalTempURL)

                                    let convertedFile = ConvertedFile(
                                        originalURL: inputURL,
                                        tempURL: finalTempURL,
                                        fileName: fileName
                                    )

                                    // Replace the converting file with the converted file
                                    files[fileIndex] = .converted(convertedFile)
                                    print("Files array now has \(files.count) items after fallback")
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
                        let baseName = inputURL.deletingPathExtension().lastPathComponent
                        let fileName = "\(baseName).\(outputService.fileExtension)"

                        // Move to final location with proper filename
                        let finalTempURL = FileManager.default.temporaryDirectory
                            .appendingPathComponent(UUID().uuidString)
                            .appendingPathComponent(fileName)
                        try FileManager.default.createDirectory(at: finalTempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try FileManager.default.moveItem(at: tempURL, to: finalTempURL)

                        let convertedFile = ConvertedFile(
                            originalURL: inputURL,
                            tempURL: finalTempURL,
                            fileName: fileName
                        )

                        // Replace the converting file with the converted file
                        if let fileIndex = files.firstIndex(where: { $0.url == inputURL }) {
                            files[fileIndex] = .converted(convertedFile)
                        }
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
                    if playSounds {
                    failureSound?.play()
                }
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

        // Count successfully converted files
        let convertedCount = files.filter {
            if case .converted = $0 { return true }
            return false
        }.count

        // Only play completion sound if we have at least one successful conversion
        if convertingCount == 0 && convertedCount > 0 {
            print("Batch conversion completed with \(convertedCount) successful conversions")
            // Play completion sound
            if playSounds {
                completionSound?.play()
            }
        }

        isConverting = false
        currentConversionFile = ""
        conversionProgress = (current: 0, total: 0)
        conversionTask = nil
    }

    private func saveFile(_ convertedFile: ConvertedFile) {
        if saveToSourceFolder {
            // Save directly to source folder
            let sourceFolder = convertedFile.originalURL.deletingLastPathComponent()
            let destinationURL = sourceFolder.appendingPathComponent(convertedFile.fileName)

            do {
                // Check if file already exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    // Show save panel if file exists
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = convertedFile.fileName
                    panel.directoryURL = sourceFolder
                    panel.allowedContentTypes = [UTType(filenameExtension: outputService.fileExtension)!]

                    if panel.runModal() == .OK, let url = panel.url {
                        try FileManager.default.copyItem(at: convertedFile.tempURL, to: url)
                        addToHistory(convertedFile: convertedFile, savedURL: url)
                    }
                } else {
                    // Copy directly if file doesn't exist
                    try FileManager.default.copyItem(at: convertedFile.tempURL, to: destinationURL)
                    addToHistory(convertedFile: convertedFile, savedURL: destinationURL)
                }
            } catch {
                showError(error.localizedDescription)
            }
        } else {
            // Show save panel
            let panel = NSSavePanel()
            panel.nameFieldStringValue = convertedFile.fileName
            panel.allowedContentTypes = [UTType(filenameExtension: outputService.fileExtension)!]

            if panel.runModal() == .OK, let url = panel.url {
                do {
                    // Copy the temp file to the destination
                    try FileManager.default.copyItem(at: convertedFile.tempURL, to: url)
                    addToHistory(convertedFile: convertedFile, savedURL: url)
                } catch {
                    showError(error.localizedDescription)
                }
            }
        }
    }

    private func addToHistory(convertedFile: ConvertedFile, savedURL: URL) {
        let inputFormat = convertedFile.originalURL.pathExtension.uppercased()
        let outputFormat = savedURL.pathExtension.uppercased()
        savedHistoryManager.addConversion(
            inputFileName: convertedFile.originalURL.lastPathComponent,
            inputFormat: inputFormat,
            outputFormat: outputFormat,
            outputFileURL: savedURL
        )
    }

    private func saveFile(data: Data, fileName: String, originalURL: URL) {
        if saveToSourceFolder {
            // Save directly to source folder
            let sourceFolder = originalURL.deletingLastPathComponent()
            let destinationURL = sourceFolder.appendingPathComponent(fileName)

            do {
                // Check if file already exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    // Show save panel if file exists
                    let panel = NSSavePanel()
                    panel.nameFieldStringValue = fileName
                    panel.directoryURL = sourceFolder
                    panel.allowedContentTypes = [UTType(filenameExtension: outputService.fileExtension)!]

                    if panel.runModal() == .OK, let url = panel.url {
                        try data.write(to: url)
                        addToHistory(originalURL: originalURL, savedURL: url)
                    }
                } else {
                    // Write directly if file doesn't exist
                    try data.write(to: destinationURL)
                    addToHistory(originalURL: originalURL, savedURL: destinationURL)
                }
            } catch {
                showError(error.localizedDescription)
            }
        } else {
            // Show save panel
            let panel = NSSavePanel()
            panel.nameFieldStringValue = fileName
            panel.allowedContentTypes = [UTType(filenameExtension: outputService.fileExtension)!]

            if panel.runModal() == .OK, let url = panel.url {
                do {
                    try data.write(to: url)
                    addToHistory(originalURL: originalURL, savedURL: url)
                } catch {
                    showError(error.localizedDescription)
                }
            }
        }
    }

    private func addToHistory(originalURL: URL, savedURL: URL) {
        let inputFormat = originalURL.pathExtension.uppercased()
        let outputFormat = savedURL.pathExtension.uppercased()
        savedHistoryManager.addConversion(
            inputFileName: originalURL.lastPathComponent,
            inputFormat: inputFormat,
            outputFormat: outputFormat,
            outputFileURL: savedURL
        )
    }

    private func saveAllFiles() {
        let convertedFilesList = files.compactMap { file in
            if case .converted(let convertedFile) = file {
                return convertedFile
            } else {
                return nil
            }
        }

        if saveToSourceFolder {
            // Save all files to their respective source folders
            for file in convertedFilesList {
                let sourceFolder = file.originalURL.deletingLastPathComponent()
                let fileURL = sourceFolder.appendingPathComponent(file.fileName)

                do {
                    // Check if file already exists
                    if FileManager.default.fileExists(atPath: fileURL.path) {
                        // For batch save with existing files, append a number
                        let baseFileName = (file.fileName as NSString).deletingPathExtension
                        let fileExtension = (file.fileName as NSString).pathExtension
                        var counter = 1
                        var newFileURL = fileURL

                        while FileManager.default.fileExists(atPath: newFileURL.path) {
                            let newFileName = "\(baseFileName)_\(counter).\(fileExtension)"
                            newFileURL = sourceFolder.appendingPathComponent(newFileName)
                            counter += 1
                        }

                        try FileManager.default.copyItem(at: file.tempURL, to: newFileURL)
                        addToHistory(convertedFile: file, savedURL: newFileURL)
                    } else {
                        // Copy directly if file doesn't exist
                        try FileManager.default.copyItem(at: file.tempURL, to: fileURL)
                        addToHistory(convertedFile: file, savedURL: fileURL)
                    }
                } catch {
                    showError("Failed to save \(file.fileName): \(error.localizedDescription)")
                    return
                }
            }
        } else {
            // Show folder selection panel
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose Folder"

            if panel.runModal() == .OK, let folderURL = panel.url {
                for file in convertedFilesList {
                    let fileURL = folderURL.appendingPathComponent(file.fileName)
                    do {
                        // Copy the temp file to the destination
                        try FileManager.default.copyItem(at: file.tempURL, to: fileURL)
                        addToHistory(convertedFile: file, savedURL: fileURL)
                    } catch {
                        showError("Failed to save \(file.fileName): \(error.localizedDescription)")
                        return
                    }
                }
            }
        }
    }

    private func isConversionServiceAvailable() -> Bool {
        switch outputService {
        case .pandoc:
            return pandocWrapper != nil
        case .imagemagick:
            return imageMagickWrapper != nil
        case .ffmpeg:
            return ffmpegWrapper != nil
        case .ocr:
            return ocrService != nil
        case .tts:
            return ttsWrapper != nil
        case .archive:
            return true // Archive service is always available
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

        // If no files, reset to a default service
        if files.isEmpty {
            outputService = .pandoc(.html)
            return
        }

        // If current outputService is still compatible, keep it
        if compatibleServices.contains(where: { $0.0 == outputService }) {
            return
        }

        // Otherwise, select the first compatible option if available
        if let firstService = compatibleServices.first {
            outputService = firstService.0
        }
    }

    private func detectInputAudioBitDepth() {
        // Reset audio properties
        inputAudioBitDepth = nil
        inputAudioSampleRate = nil
        inputAudioChannels = nil
        inputAudioBitRate = nil

        // Detect for both audio and video files (video may have audio tracks)
        guard let firstFile = files.first,
              let url = firstFile.url else { return }

        // Detect audio properties asynchronously using hybrid approach
        Task {
            do {
                // Create detector with FFmpeg fallback if available
                let detector = AudioPropertyDetector(ffmpegWrapper: ffmpegWrapper)
                let properties = try await detector.detectProperties(from: url)

                await MainActor.run {
                    self.inputAudioBitDepth = properties.bitDepth
                    self.inputAudioSampleRate = properties.sampleRate
                    self.inputAudioChannels = properties.channels
                    self.inputAudioBitRate = properties.bitRate

                    // Auto-update sample size if output is lossless
                    if case .ffmpeg(let outputFormat) = outputService,
                       let config = FormatRegistry.shared.config(for: outputFormat),
                       config.isLossless,
                       let bitDepth = properties.bitDepth {
                        updateSampleSizeForBitDepth(bitDepth)
                    }

                    // Don't auto-update sample rate and channels when they're automatic
                    // Automatic means FFmpeg will preserve the source values
                }
            } catch {
                print("Failed to detect audio properties: \(error)")
            }
        }
    }

    private func updateSampleSizeForBitDepth(_ bitDepth: Int) {
        // Map bit depth to AudioSampleSize
        let targetSampleSize: AudioSampleSize?

        // Check if exact match is available
        if let outputFormat = currentFFmpegFormat,
           let config = FormatRegistry.shared.config(for: outputFormat),
           config.supportsSampleSize {

            let availableSizes = config.availableSampleSizes

            // Find exact match
            if availableSizes.contains(where: { $0.rawValue == bitDepth }) {
                targetSampleSize = AudioSampleSize(rawValue: bitDepth)
            } else {
                // Find highest available that's still <= source (no upsampling)
                let lowerSizes = availableSizes.filter { $0.rawValue <= bitDepth }
                if let bestMatch = lowerSizes.max(by: { $0.rawValue < $1.rawValue }) {
                    targetSampleSize = bestMatch
                } else {
                    // Source is lower than all available, use minimum
                    targetSampleSize = availableSizes.min(by: { $0.rawValue < $1.rawValue })
                }
            }

            // Update the audio options
            if let newSize = targetSampleSize {
                audioOptions.sampleSize = newSize
            }
        }
    }

    private func updateSampleRateForInput(_ sampleRate: Int) {
        // Only update if automatic is selected
        guard audioOptions.sampleRate == .automatic else { return }

        // Find matching AudioSampleRate
        if let matchingRate = AudioSampleRate.allCases.first(where: { $0.value == sampleRate }) {
            audioOptions.sampleRate = matchingRate
        }
    }

    private func updateChannelsForInput(_ channels: Int) {
        // Only update if automatic is selected
        guard audioOptions.channels == .automatic else { return }

        // Map to AudioChannels
        switch channels {
        case 1:
            audioOptions.channels = .mono
        case 2:
            audioOptions.channels = .stereo
        default:
            // Keep automatic for multi-channel
            break
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

        // Add OCR/Text extraction for PDFs and images
        let hasPDFs = inputURLs.contains { url in
            url.pathExtension.lowercased() == "pdf"
        }
        let hasImages = !imageFormats.isEmpty

        if hasPDFs && hasImages {
            // Both PDFs and images: show generic text option
            compatibleServices.append((.ocr(.txt), "Text"))
        } else if hasPDFs {
            // Only PDFs: show both extraction methods
            compatibleServices.append((.ocr(.txtExtract), "Text (Extract)"))
            compatibleServices.append((.ocr(.txtOCR), "Text (OCR)"))
        } else if hasImages {
            // Only images: show generic text option
            compatibleServices.append((.ocr(.txt), "Text"))
        }

        // Add TTS for text files
        let hasTextFiles = inputURLs.contains { url in
            let ext = url.pathExtension.lowercased()
            let isText = ext == "txt" || ext == "text"
            let pandocFormat = PandocFormat.detectFormat(from: url)
            let isPandocPlain = pandocFormat == .plain

            // Check if it's a text file by extension or if Pandoc detected it as plain text
            return isText || isPandocPlain
        }

        if hasTextFiles {
            // Add TTS audio output formats
            compatibleServices.append(contentsOf: TTSFormat.allCases.map { format in
                (.tts(format), "\(format.displayName) (TTS)")
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
        case .ocr(let format):
            switch format {
            case .txt:
                return "OCR to txt"
            case .txtExtract:
                return "Extract text to txt"
            case .txtOCR:
                return "OCR to txt"
            }
        case .tts(let format):
            return "Text to \(format.displayName)"
        case .archive(let format):
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
        let isImageOutput = if case .imagemagick = outputService { true } else { false }
        return hasInputRequiringDpi && isImageOutput
    }

    private var inputFFmpegFormat: FFmpegFormat? {
        // Get the format of the first input file
        guard let firstFile = files.first,
              let url = firstFile.url else { return nil }

        return FFmpegFormat.detectFormat(from: url)
    }

    private var shouldShowAudioOptions: Bool {
        // Show audio options when:
        // 1. We're converting to an audio format with FFmpeg
        if case .ffmpeg(let format) = outputService {
            return !format.isVideo
        }
        return false
    }

    private var shouldShowVideoOptions: Bool {
        // Show video options when:
        // 1. We're converting to a video format with FFmpeg
        if case .ffmpeg(let format) = outputService {
            return format.isVideo
        }
        return false
    }

    private var shouldShowOCROptions: Bool {
        // Show OCR options only for actual OCR (not for text extraction)
        if case .ocr(let format) = outputService {
            switch format {
            case .txt, .txtOCR:
                return true
            case .txtExtract:
                return false
            }
        }
        return false
    }

    private var shouldShowTTSOptions: Bool {
        // Show TTS options when converting text to speech
        if case .tts = outputService {
            return true
        }
        return false
    }

    private var shouldShowArchiveOptions: Bool {
        // Show archive options when creating archives
        if case .archive = outputService {
            return true
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
        case 1_200: return 4
        case 2_400: return 5
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
            if isPDFMergeMode {
                let index = files.firstIndex { $0.id == fileState.id } ?? 0
                FileRow(
                    url: url,
                    isPDFMergeMode: true,
                    index: index,
                    totalFiles: files.count,
                    onMoveUp: {
                        moveFile(at: index, direction: -1)
                    },
                    onMoveDown: {
                        moveFile(at: index, direction: 1)
                    },
                    onRemove: {
                        files.removeAll { $0.id == fileState.id }
                        updateOutputService()
                    }
                )
            } else {
                FileRow(
                    url: url,
                    isPDFMergeMode: false,
                    index: 0,
                    totalFiles: 1,
                    onMoveUp: {},
                    onMoveDown: {},
                    onRemove: {
                        files.removeAll { $0.id == fileState.id }
                        updateOutputService()
                    }
                )
            }
        case .converting(let url, let fileName):
            ConvertingFileRow(url: url, fileName: fileName)
        case .converted(let convertedFile):
            ConvertedFileRow(
                file: convertedFile,
                onSave: {
                    saveFile(convertedFile)
                }
            )
        case .error(let url, let message):
            ErrorFileRow(
                url: url,
                fileName: fileState.fileName,
                message: message,
                onRemove: {
                    files.removeAll { $0.id == fileState.id }
                    updateOutputService()
                }
            )
        }
    }

    private func mapImageFormatToPDFKitFormat(_ format: ImageFormat) -> PDFKitService.PDFConversionOptions.ImageFormat {
        switch format {
        case .png:
            return .png
        case .jpeg, .jpg:
            return .jpeg
        case .tiff, .tif:
            return .tiff
        default:
            // Default to PNG for unsupported formats
            return .png
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
    let container = (try? ModelContainer(for: ConversionRecord.self, configurations: config)) ??
                    (try! ModelContainer(for: ConversionRecord.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let context = container.mainContext
    let manager = SavedHistoryManager(modelContext: context)
    let fileController = FileSelectionController()

    ConverterView(savedHistoryManager: manager, fileSelectionController: fileController)
        .modelContainer(container)
}
