//
//  ConverterView.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ActivityIndicatorView
import ProgressIndicatorView

struct FilePreviewView: View {
    let data: Data?
    let url: URL?
    let fileName: String
    
    init(data: Data, fileName: String) {
        self.data = data
        self.url = nil
        self.fileName = fileName
    }
    
    init(url: URL) {
        self.data = nil
        self.url = url
        self.fileName = url.lastPathComponent
    }
    
    var body: some View {
        if let data = getFileData() {
            let isImage = ImageFormat.detectFormat(from: URL(fileURLWithPath: fileName)) != nil
            
            if isImage {
                if let nsImage = NSImage(data: data) {
                    let isPDF = fileName.lowercased().hasSuffix(".pdf")
                    
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .background(isPDF ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(maxWidth: 200, maxHeight: 150)
                } else {
                    fileIcon
                }
            } else {
                fileIcon
            }
        } else {
            fileIcon
        }
    }
    
    private var fileIcon: some View {
        Image(nsImage: iconForFile(fileName: fileName))
            .resizable()
            .frame(width: 64, height: 64)
    }
    
    private func getFileData() -> Data? {
        if let data = data {
            return data
        } else if let url = url {
            return try? Data(contentsOf: url)
        }
        return nil
    }
    
    private func iconForFile(fileName: String) -> NSImage {
        if let url = url {
            return NSWorkspace.shared.icon(forFile: url.path)
        } else {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: tempURL.path) {
                FileManager.default.createFile(atPath: tempURL.path, contents: Data(), attributes: nil)
            }
            let icon = NSWorkspace.shared.icon(forFile: tempURL.path)
            try? FileManager.default.removeItem(at: tempURL)
            return icon
        }
    }
}

struct PreviewButton: View {
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "eye")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.gray.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Quick Look")
    }
}

struct RemoveButton: View {
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(4)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.gray.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct ClearButton: View {
    let label: String
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Label(label, systemImage: "xmark")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(isHovering ? 0.2 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            isHovering = hovering
        }
        .disabled(isDisabled)
    }
}

struct SaveButton: View {
    let action: () -> Void
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.0, green: 0.5, blue: 0.0))
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color(red: 0.0, green: 0.5, blue: 0.0).opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
            // Action handled by Button
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}

struct SaveAllButton: View {
    let label: String
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Label(label, systemImage: "arrow.down.to.line.compact")
                .font(.body)
                .foregroundStyle(Color(red: 0.0, green: 0.5, blue: 0.0))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(red: 0.0, green: 0.5, blue: 0.0).opacity(isHovering ? 0.15 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct FileRow: View {
    let url: URL
    let onRemove: () -> Void
    @State private var isHoveringRow = false
    
    var body: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 32, height: 32)
                .fixedSize()
            
            Text(url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            HStack(spacing: 4) {
                if isHoveringRow {
                    PreviewButton(action: {
                        QuickLookManager.shared.previewFile(at: url)
                    })
                    .transition(.opacity)
                }
                
                RemoveButton(action: onRemove)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringRow = hovering
            }
        }
    }
}

struct FileContentRow: View {
    let url: URL
    let onRemove: () -> Void
    @State private var isHoveringRow = false
    
    var body: some View {
        HStack {
            Text(url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            HStack(spacing: 4) {
                if isHoveringRow {
                    PreviewButton(action: {
                        QuickLookManager.shared.previewFile(at: url)
                    })
                    .transition(.opacity)
                }
                
                RemoveButton(action: onRemove)
            }
        }
        .frame(height: 32)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringRow = hovering
            }
        }
    }
}


struct ConvertedFileContentRow: View {
    let file: ConvertedFile
    let onSave: () -> Void
    @State private var isHoveringRow = false
    
    var body: some View {
        HStack {
            Text(file.fileName)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            HStack(spacing: 4) {
                if isHoveringRow {
                    PreviewButton(action: {
                        QuickLookManager.shared.previewFile(data: file.data, fileName: file.fileName)
                    })
                    .transition(.opacity)
                }
                
                SaveButton {
                    onSave()
                }
            }
        }
        .frame(height: 32)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringRow = hovering
            }
        }
    }
}

struct ConvertedFile: Identifiable {
    let id = UUID()
    let originalURL: URL
    let data: Data
    let fileName: String
}

struct FormatPicker: View {
    @Binding var selectedService: ConversionService
    let inputFileURLs: [URL]
    
    static let documentFormats: [(PandocFormat, String)] = [
        // Common formats
        (.markdown, "Markdown"),
        (.html, "HTML"),
        (.pdf, "PDF"),
        (.docx, "Word Document (DOCX)"),
        (.latex, "LaTeX"),
        (.plain, "Plain Text"),
        (.rtf, "Rich Text Format (RTF)"),
        (.epub, "EPUB"),
        
        // Markdown variants
        (.commonmark, "CommonMark"),
        (.gfm, "GitHub Flavored Markdown"),
        (.markdownStrict, "Strict Markdown"),
        (.markdownPhpextra, "PHP Markdown Extra"),
        (.markdownMmd, "MultiMarkdown"),
        
        // Lightweight markup
        (.rst, "reStructuredText"),
        (.asciidoc, "AsciiDoc"),
        (.textile, "Textile"),
        (.org, "Org Mode"),
        (.muse, "Emacs Muse"),
        (.creole, "Creole"),
        (.djot, "Djot"),
        (.markua, "Markua"),
        (.txt2tags, "txt2tags"),
        
        // Wiki formats
        (.mediawiki, "MediaWiki"),
        (.dokuwiki, "DokuWiki"),
        (.tikiwiki, "TikiWiki"),
        (.twiki, "TWiki"),
        (.vimwiki, "Vimwiki"),
        (.xwiki, "XWiki"),
        (.zimwiki, "ZimWiki"),
        (.jira, "Jira Wiki"),
        
        // HTML variants
        (.html4, "HTML 4"),
        (.html5, "HTML 5"),
        (.chunkedhtml, "Chunked HTML"),
        
        // Ebook formats
        (.epub2, "EPUB 2"),
        (.epub3, "EPUB 3"),
        (.fb2, "FictionBook2"),
        
        // Documentation formats
        (.man, "Man Page"),
        (.ms, "Roff ms"),
        (.mdoc, "mdoc"),
        (.texinfo, "GNU TexInfo"),
        (.haddock, "Haddock"),
        
        // XML formats
        (.docbook, "DocBook"),
        (.docbook4, "DocBook 4"),
        (.docbook5, "DocBook 5"),
        (.jats, "JATS"),
        (.jatsArchiving, "JATS Archiving"),
        (.jatsPublishing, "JATS Publishing"),
        (.jatsArticleauthoring, "JATS Article Authoring"),
        (.bits, "BITS"),
        (.tei, "TEI Simple"),
        (.opml, "OPML"),
        (.opendocument, "OpenDocument XML"),
        
        // Office formats
        (.odt, "OpenDocument Text (ODT)"),
        (.powerpoint, "PowerPoint (PPTX)"),
        (.openoffice, "OpenOffice"),
        
        // Academic formats
        (.context, "ConTeXt"),
        (.biblatex, "BibLaTeX"),
        (.bibtex, "BibTeX"),
        (.csljson, "CSL JSON"),
        (.ris, "RIS"),
        (.endnotexml, "EndNote XML"),
        
        // Presentation formats
        (.beamer, "LaTeX Beamer"),
        (.slidy, "Slidy"),
        (.slideous, "Slideous"),
        (.dzslides, "DZSlides"),
        (.revealjs, "reveal.js"),
        (.s5, "S5"),
        
        // Other formats
        (.json, "JSON"),
        (.native, "Native"),
        (.icml, "InDesign ICML"),
        (.typst, "Typst"),
        (.ipynb, "Jupyter Notebook"),
        (.csv, "CSV"),
        (.tsv, "TSV"),
        (.ansi, "ANSI Terminal")
    ]
    
    static let imageFormats: [(ImageFormat, String)] = [
        (.jpeg, "JPEG"),
        (.png, "PNG"),
        (.gif, "GIF"),
        (.bmp, "BMP"),
        (.tiff, "TIFF"),
        (.webp, "WebP"),
        (.heic, "HEIC"),
        (.heif, "HEIF"),
        (.pdf, "PDF (Image)"),
        (.svg, "SVG"),
        (.ico, "ICO")
    ]
    
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
            return Self.imageFormats.filter { compatibleImageFormats.contains($0.0) }.map { (.imagemagick($0.0), $0.1) }.sorted { $0.1 < $1.1 }
        }
        
        // Detect if inputs are documents or images (excluding PDFs)
        let documentFormats = inputFileURLs.compactMap { url in
            url.pathExtension.lowercased() == "pdf" ? nil : PandocFormat.detectFormat(from: url)
        }
        let imageFormats = inputFileURLs.compactMap { url in
            url.pathExtension.lowercased() == "pdf" ? nil : ImageFormat.detectFormat(from: url)
        }
        
        var compatibleServices: [(ConversionService, String)] = []
        
        if !documentFormats.isEmpty {
            // Document conversion with Pandoc
            var compatiblePandocFormats = Set(PandocFormat.compatibleOutputFormats(for: documentFormats[0]))
            for format in documentFormats.dropFirst() {
                compatiblePandocFormats.formIntersection(PandocFormat.compatibleOutputFormats(for: format))
            }
            compatibleServices.append(contentsOf: Self.documentFormats.filter { compatiblePandocFormats.contains($0.0) }.map { (.pandoc($0.0), $0.1) })
        }
        
        if !imageFormats.isEmpty {
            // Image conversion with ImageMagick
            let compatibleImageFormats = ImageFormat.outputFormats
            compatibleServices.append(contentsOf: Self.imageFormats.filter { compatibleImageFormats.contains($0.0) }.map { (.imagemagick($0.0), $0.1) })
        }
        
        return compatibleServices.sorted { $0.1 < $1.1 }
    }
    
    var body: some View {
        Picker("Output Format", selection: $selectedService) {
            ForEach(compatibleServices, id: \.0) { service, name in
                Text(name).tag(service)
            }
        }
        .pickerStyle(.menu)
        .disabled(inputFileURLs.isEmpty)
    }
    
    private func getServiceDisplayName(_ service: ConversionService) -> String {
        switch service {
        case .pandoc(let format):
            return Self.documentFormats.first { $0.0 == format }?.1 ?? format.rawValue
        case .imagemagick(let format):
            return Self.imageFormats.first { $0.0 == format }?.1 ?? format.displayName
        }
    }
    
    private func servicesEqual(_ service1: ConversionService, _ service2: ConversionService) -> Bool {
        switch (service1, service2) {
        case (.pandoc(let f1), .pandoc(let f2)):
            return f1 == f2
        case (.imagemagick(let f1), .imagemagick(let f2)):
            return f1 == f2
        default:
            return false
        }
    }
}

enum ConversionService: Hashable {
    case pandoc(PandocFormat)
    case imagemagick(ImageFormat)
    
    var fileExtension: String {
        switch self {
        case .pandoc(let format):
            return format.fileExtension
        case .imagemagick(let format):
            return format.fileExtension
        }
    }
}

struct ConverterView: View {
    @State private var inputFileURLs: [URL] = []
    @State private var outputService: ConversionService = .pandoc(.html)
    @State private var isConverting = false
    @State private var currentConversionFile = ""
    @State private var conversionProgress = (current: 0, total: 0)
    @State private var convertedFiles: [ConvertedFile] = []
    @State private var errorMessage: String?
    @AppStorage("imageQuality") private var imageQuality: Double = 85
    @AppStorage("useLossyCompression") private var useLossyCompression: Bool = false
    @AppStorage("removeExifMetadata") private var removeExifMetadata: Bool = false
    @State private var isTargeted = false
    @State private var showingRecentConversions = false
    @AppStorage("pdfToDpi") private var pdfToDpi: Int = 300
    
    @State private var pandocWrapper: PandocWrapper?
    @State private var pandocInitError: String?
    @State private var imageMagickWrapper: ImageMagickWrapper?
    @State private var imageMagickInitError: String?
    
    @StateObject private var historyManager = ConversionHistoryManager()
    
    // MARK: - Input pane
    var body: some View {
        HStack(spacing: 0) {
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isTargeted ? Color.accentColor : Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        )
                    
                    if !inputFileURLs.isEmpty {
                        if inputFileURLs.count == 1 {
                            VStack(spacing: 0) {
                                VStack(spacing: 12) {
                                    let fileURL = inputFileURLs[0]
                                    
                                    FilePreviewView(url: fileURL)
                                    
                                    Text(fileURL.lastPathComponent)
                                        .font(.headline)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                VStack(spacing: 0) {
                                    Divider()
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 12) {
                                        PreviewButton(action: {
                                            QuickLookManager.shared.previewFile(at: inputFileURLs[0])
                                        })
                                        
                                        ClearButton(
                                            label: "Clear",
                                            isDisabled: false
                                        ) {
                                            inputFileURLs = []
                                            convertedFiles = []
                                            errorMessage = nil
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                }
                            }
                        } else {
                            VStack(spacing: 0) {
                                ScrollView {
                                    HStack(alignment: .top, spacing: 0) {
                                        // Icon column
                                        VStack(spacing: 8) {
                                            ForEach(inputFileURLs, id: \.self) { url in
                                                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                                    .resizable()
                                                    .frame(width: 32, height: 32)
                                                    .fixedSize()
                                            }
                                        }
                                        .padding(.leading, 16)
                                        .padding(.trailing, 12)
                                        .padding(.vertical, 16)
                                        
                                        // File content column
                                        VStack(spacing: 8) {
                                            ForEach(inputFileURLs, id: \.self) { url in
                                                FileContentRow(
                                                    url: url,
                                                    onRemove: {
                                                        inputFileURLs.removeAll { $0 == url }
                                                        if inputFileURLs.isEmpty {
                                                            convertedFiles = []
                                                            errorMessage = nil
                                                                        }
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.trailing, 16)
                                        .padding(.vertical, 16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                
                                VStack(spacing: 0) {
                                    Divider()
                                        .padding(.horizontal)
                                    
                                    ClearButton(
                                        label: "Clear All",
                                        isDisabled: false
                                    ) {
                                        inputFileURLs = []
                                        convertedFiles = []
                                        errorMessage = nil
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
                                .foregroundStyle(.quaternary)
                            
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
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                } else if let pandocError = pandocInitError {
                    Text(pandocError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
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
            
            // Convert pane (middle)
            VStack {
                FormatPicker(selectedService: $outputService, inputFileURLs: inputFileURLs)
                    .padding(.top)
                    .disabled(inputFileURLs.isEmpty)
                
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
                
                // Show EXIF metadata removal toggle for all image conversions
                if case .imagemagick = outputService, !inputFileURLs.isEmpty {
                    HStack {
                        Spacer()
                        Toggle("Strip EXIF Metadata", isOn: $removeExifMetadata)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .padding(.top, 8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.2), value: outputService)
                }
                
                // Show quality controls for lossy image conversions
                if case .imagemagick(let format) = outputService, !inputFileURLs.isEmpty, format.isLossy {
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
                
                Spacer()
                
                VStack {
                    Button(action: {
                        print("Convert button clicked")
                        errorMessage = "Starting conversion..."
                        Task {
                            await convertFile()
                        }
                    }) {
                        Label("Convert", systemImage: "arrowshape.zigzag.right")
                            .font(.title3)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .disabled(inputFileURLs.isEmpty || isConverting || !isConversionServiceAvailable())
                    .controlSize(.large)
                    .padding(.bottom)
                }
            }
            .padding()
            .frame(width: 300)
            
            // MARK: - Output pane
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        )
                    
                    if isConverting {
                        VStack(spacing: 12) {
                            if conversionProgress.total > 1 {
                                // Use ProgressIndicatorView for multiple files
                                let progress = Double(conversionProgress.current - 1) / Double(conversionProgress.total)
                                ProgressIndicatorView(isVisible: .constant(true), type: .impulseBar(progress: .constant(progress), backgroundColor: .gray))
                                    .frame(width: 120, height: 6)
                                    .foregroundStyle(.blue)
                                
                                Text("Converting file \(conversionProgress.current) of \(conversionProgress.total)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                // Use ActivityIndicatorView for single files
                                ActivityIndicatorView(isVisible: .constant(true), type: .equalizer(count: 5))
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(.blue)
                            }
                            
                            if !currentConversionFile.isEmpty {
                                Text(currentConversionFile)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .padding()
                    } else if !convertedFiles.isEmpty {
                        if convertedFiles.count == 1 {
                            VStack(spacing: 0) {
                                VStack(spacing: 12) {
                                    let file = convertedFiles[0]
                                    
                                    FilePreviewView(data: file.data, fileName: file.fileName)
                                    
                                    Text(file.fileName)
                                        .font(.headline)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                
                                VStack(spacing: 0) {
                                    Divider()
                                        .padding(.horizontal)
                                    
                                    HStack(spacing: 12) {
                                        PreviewButton(action: {
                                            QuickLookManager.shared.previewFile(data: convertedFiles[0].data, fileName: convertedFiles[0].fileName)
                                        })
                                        
                                        SaveAllButton(
                                            label: "Save"
                                        ) {
                                            saveFile(data: convertedFiles[0].data, fileName: convertedFiles[0].fileName, originalURL: convertedFiles[0].originalURL)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                }
                            }
                        } else {
                            VStack(spacing: 0) {
                                ScrollView {
                                    HStack(alignment: .top, spacing: 0) {
                                        // Icon column
                                        VStack(spacing: 8) {
                                            ForEach(convertedFiles) { file in
                                                Image(nsImage: self.iconForFile(fileName: file.fileName))
                                                    .resizable()
                                                    .frame(width: 32, height: 32)
                                                    .fixedSize()
                                            }
                                        }
                                        .padding(.leading, 16)
                                        .padding(.trailing, 12)
                                        .padding(.vertical, 16)
                                        
                                        // File content column
                                        VStack(spacing: 8) {
                                            ForEach(convertedFiles) { file in
                                                ConvertedFileContentRow(
                                                    file: file,
                                                    onSave: {
                                                        saveFile(data: file.data, fileName: file.fileName, originalURL: file.originalURL)
                                                    }
                                                )
                                            }
                                        }
                                        .padding(.trailing, 16)
                                        .padding(.vertical, 16)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                                
                                VStack(spacing: 0) {
                                    Divider()
                                        .padding(.horizontal)
                                    
                                    SaveAllButton(
                                        label: "Save All"
                                    ) {
                                        saveAllFiles()
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                                }
                            }
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image("document.badge.sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(.quaternary)
                            
                            Text("Converted Files Appear Here")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Button("") {
                                // Invisible button for alignment
                            }
                            .buttonStyle(.bordered)
                            .opacity(0)
                            .disabled(true)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingRecentConversions.toggle()
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .help("Recent Conversions")
                }
                .popover(isPresented: $showingRecentConversions, arrowEdge: .bottom) {
                    RecentConversionsView(historyManager: historyManager)
                        .frame(
                            width: 400,
                            height: historyManager.recentConversions.isEmpty ? 300 :
                                   min(500, max(200, CGFloat(historyManager.recentConversions.count * 60) + 100))
                        )
                }
            }
        }
        .frame(minWidth: 800, minHeight: 400)
        .onAppear {
            initializePandoc()
            initializeImageMagick()
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
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (urlData, error) in
                DispatchQueue.main.async {
                    if let urlData = urlData as? Data,
                       let path = String(data: urlData, encoding: .utf8),
                       let url = URL(string: path) {
                        
                        // Check if file already exists
                        if self.inputFileURLs.contains(url) {
                            return
                        }
                        
                        // Detect format of the new file (document or image)
                        let newDocumentFormat = PandocFormat.detectFormat(from: url)
                        var newImageFormat = ImageFormat.detectFormat(from: url)
                        
                        // Special handling for PDF - can be treated as both document and image
                        if url.pathExtension.lowercased() == "pdf" {
                            newImageFormat = .pdf
                        }
                        
                        guard newDocumentFormat != nil || newImageFormat != nil else {
                            self.errorMessage = "Unsupported file type: \(url.pathExtension)"
                            return
                        }
                        
                        // If this is the first file, allow it
                        if self.inputFileURLs.isEmpty {
                            self.inputFileURLs.append(url)
                            self.errorMessage = nil
                            self.updateOutputServiceToDefault()
                            return
                        }
                        
                        // Check if the new file is compatible with existing files
                        let existingDocumentFormats = self.inputFileURLs.compactMap { PandocFormat.detectFormat(from: $0) }
                        let existingImageFormats = self.inputFileURLs.compactMap { ImageFormat.detectFormat(from: $0) }
                        
                        let isNewDocument = newDocumentFormat != nil
                        let isNewImage = newImageFormat != nil
                        let hasExistingDocuments = !existingDocumentFormats.isEmpty
                        let hasExistingImages = !existingImageFormats.isEmpty
                        
                        // Allow if new file type matches existing file types
                        // Special case: PDFs can be treated as both documents and images
                        let isPDFMixing = url.pathExtension.lowercased() == "pdf" &&
                                         self.inputFileURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
                        
                        if (isNewDocument && hasExistingDocuments && !hasExistingImages) ||
                           (isNewImage && hasExistingImages && !hasExistingDocuments) ||
                           isPDFMixing {
                            self.inputFileURLs.append(url)
                            self.errorMessage = nil
                            self.updateOutputServiceToDefault()
                        } else {
                            // Replace existing files with the new incompatible file
                            self.inputFileURLs = [url]
                            self.convertedFiles = []
                            self.errorMessage = nil
                            self.updateOutputServiceToDefault()
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
                if inputFileURLs.contains(url) {
                    continue
                }
                
                // Detect format of the new file (document or image)
                let newDocumentFormat = PandocFormat.detectFormat(from: url)
                var newImageFormat = ImageFormat.detectFormat(from: url)
                
                // Special handling for PDF - can be treated as both document and image
                if url.pathExtension.lowercased() == "pdf" {
                    newImageFormat = .pdf
                }
                
                guard newDocumentFormat != nil || newImageFormat != nil else {
                    errorMessage = "Unsupported file type: \(url.pathExtension)"
                    continue
                }
                
                // If this is the first file, allow it
                if inputFileURLs.isEmpty {
                    inputFileURLs.append(url)
                    updateOutputServiceToDefault()
                    continue
                }
                
                // Check if the new file is compatible with existing files
                let existingDocumentFormats = inputFileURLs.compactMap { PandocFormat.detectFormat(from: $0) }
                let existingImageFormats = inputFileURLs.compactMap { ImageFormat.detectFormat(from: $0) }
                
                let isNewDocument = newDocumentFormat != nil
                let isNewImage = newImageFormat != nil
                let hasExistingDocuments = !existingDocumentFormats.isEmpty
                let hasExistingImages = !existingImageFormats.isEmpty
                
                // Allow if new file type matches existing file types
                // Special case: PDFs can be treated as both documents and images
                let isPDFMixing = url.pathExtension.lowercased() == "pdf" &&
                                 inputFileURLs.allSatisfy { $0.pathExtension.lowercased() == "pdf" }
                
                if (isNewDocument && hasExistingDocuments && !hasExistingImages) ||
                   (isNewImage && hasExistingImages && !hasExistingDocuments) ||
                   isPDFMixing {
                    inputFileURLs.append(url)
                    updateOutputServiceToDefault()
                } else {
                    // Replace existing files with the new incompatible file
                    inputFileURLs = [url]
                    convertedFiles = []
                    errorMessage = nil
                    updateOutputServiceToDefault()
                    break
                }
            }
            
            if errorMessage == nil {
                errorMessage = nil // Clear any previous errors if successful
            }
        }
    }
    
    private func convertFile() async {
        guard !inputFileURLs.isEmpty else {
            print("convertFile: no input files")
            return
        }
        
        // Check which service we need
        switch outputService {
        case .pandoc(_):
            guard pandocWrapper != nil else {
                print("convertFile: pandoc not available")
                errorMessage = "Pandoc is not available"
                return
            }
        case .imagemagick(_):
            guard imageMagickWrapper != nil else {
                print("convertFile: ImageMagick not available")
                errorMessage = "ImageMagick is not available"
                return
            }
        }
        
        let serviceDescription = getServiceDescription(outputService)
        print("Starting batch conversion of \(inputFileURLs.count) files to \(serviceDescription)")
        
        isConverting = true
        errorMessage = nil
        convertedFiles = []
        conversionProgress = (current: 0, total: inputFileURLs.count)
        
        for (index, inputURL) in inputFileURLs.enumerated() {
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
                    convertedFiles.append(convertedFile)
                    
                    try FileManager.default.removeItem(at: tempURL)
                    
                case .imagemagick(let format):
                    try await imageMagickWrapper!.convertImage(
                        inputURL: inputURL,
                        outputURL: tempURL,
                        to: format,
                        quality: useLossyCompression ? Int(imageQuality) : 100,
                        dpi: pdfToDpi
                    )
                    
                    // Strip EXIF metadata if requested (preserving orientation)
                    // Skip EXIF stripping for PDF conversions as they don't have original EXIF data
                    if removeExifMetadata && inputURL.pathExtension.lowercased() != "pdf" {
                        try ImageProcessor.shared.strip(exifMetadataExceptOrientation: tempURL)
                    }
                    
                    // For PDF input, ImageMagick might create multiple files
                    if inputURL.pathExtension.lowercased() == "pdf" {
                        let baseName = inputURL.deletingPathExtension().lastPathComponent
                        let tempDir = tempURL.deletingLastPathComponent()
                        let baseTempName = tempURL.deletingPathExtension().lastPathComponent
                        let ext = tempURL.pathExtension
                        
                        
                        
                        var pageIndex = 0
                        var foundFiles = false
                        
                        // Based on the debug output, ImageMagick uses: filename-N.ext
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
                                convertedFiles.append(convertedFile)
                                
                                try FileManager.default.removeItem(at: testURL)
                                foundFiles = true
                                pageIndex += 1
                            } else {
                                break
                            }
                        }
                        
                        // If no numbered files were found, check for the original filename
                        if !foundFiles && FileManager.default.fileExists(atPath: tempURL.path) {
                            let data = try Data(contentsOf: tempURL)
                            let fileName = "\(baseName).\(outputService.fileExtension)"
                            
                            let convertedFile = ConvertedFile(
                                originalURL: inputURL,
                                data: data,
                                fileName: fileName
                            )
                            convertedFiles.append(convertedFile)
                            
                            try FileManager.default.removeItem(at: tempURL)
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
                        convertedFiles.append(convertedFile)
                        
                        try FileManager.default.removeItem(at: tempURL)
                    }
                }
                
                print("Successfully converted \(inputURL.lastPathComponent)")
            } catch {
                print("Conversion failed for \(inputURL.lastPathComponent): \(error)")
                errorMessage = "Failed to convert \(inputURL.lastPathComponent): \(error.localizedDescription)"
                break
            }
        }
        
        if convertedFiles.count == inputFileURLs.count {
            print("All files converted successfully!")
        }
        
        isConverting = false
        currentConversionFile = ""
        conversionProgress = (current: 0, total: 0)
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
                historyManager.addConversion(
                    inputFileName: originalURL.lastPathComponent,
                    inputFormat: inputFormat,
                    outputFormat: outputFormat,
                    outputFileURL: url
                )
            } catch {
                errorMessage = error.localizedDescription
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
            for file in convertedFiles {
                let fileURL = folderURL.appendingPathComponent(file.fileName)
                do {
                    try file.data.write(to: fileURL)
                    
                    // Add to conversion history
                    let inputFormat = file.originalURL.pathExtension.uppercased()
                    let outputFormat = fileURL.pathExtension.uppercased()
                    historyManager.addConversion(
                        inputFileName: file.originalURL.lastPathComponent,
                        inputFormat: inputFormat,
                        outputFormat: outputFormat,
                        outputFileURL: fileURL
                    )
                } catch {
                    errorMessage = "Failed to save \(file.fileName): \(error.localizedDescription)"
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
        }
    }
    
    private func updateOutputServiceToDefault() {
        // Get compatible services and set to first one if available
        let compatibleServices = getCompatibleServices()
        if let firstService = compatibleServices.first {
            outputService = firstService.0
        }
    }
    
    private func getCompatibleServices() -> [(ConversionService, String)] {
        guard !inputFileURLs.isEmpty else {
            return []
        }
        
        // Detect if inputs are documents or images
        let documentFormats = inputFileURLs.compactMap { PandocFormat.detectFormat(from: $0) }
        var imageFormats = inputFileURLs.compactMap { ImageFormat.detectFormat(from: $0) }
        
        // Special handling for PDF - can be treated as both document and image
        let hasPDF = inputFileURLs.contains { $0.pathExtension.lowercased() == "pdf" }
        if hasPDF && imageFormats.isEmpty {
            imageFormats = [.pdf]
        }
        
        var compatibleServices: [(ConversionService, String)] = []
        
        if !documentFormats.isEmpty {
            // Document conversion with Pandoc
            var compatiblePandocFormats = Set(PandocFormat.compatibleOutputFormats(for: documentFormats[0]))
            for format in documentFormats.dropFirst() {
                compatiblePandocFormats.formIntersection(PandocFormat.compatibleOutputFormats(for: format))
            }
            compatibleServices.append(contentsOf: FormatPicker.documentFormats.filter { compatiblePandocFormats.contains($0.0) }.map { (.pandoc($0.0), $0.1) })
        }
        
        if !imageFormats.isEmpty {
            // Image conversion with ImageMagick
            let compatibleImageFormats = ImageFormat.outputFormats
            compatibleServices.append(contentsOf: FormatPicker.imageFormats.filter { compatibleImageFormats.contains($0.0) }.map { (.imagemagick($0.0), $0.1) })
        }
        
        return compatibleServices.sorted { $0.1 < $1.1 }
    }
    
    private func getServiceDescription(_ service: ConversionService) -> String {
        switch service {
        case .pandoc(let format):
            return format.rawValue
        case .imagemagick(let format):
            return format.rawValue
        }
    }
    
    private var shouldShowDpiSelector: Bool {
        // Show DPI selector when:
        // 1. We have PDF input files
        // 2. We're converting to an image format
        let hasPdfInput = inputFileURLs.contains { $0.pathExtension.lowercased() == "pdf" }
        let isImageOutput = if case .imagemagick(_) = outputService { true } else { false }
        return hasPdfInput && isImageOutput
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
    
    
    private func iconForFile(fileName: String) -> NSImage {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            FileManager.default.createFile(atPath: tempURL.path, contents: Data(), attributes: nil)
        }
        let icon = NSWorkspace.shared.icon(forFile: tempURL.path)
        try? FileManager.default.removeItem(at: tempURL)
        return icon
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
    ConverterView()
}
