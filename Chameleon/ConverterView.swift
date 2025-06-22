//
//  ConverterView.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

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
                .foregroundStyle(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.red.opacity(isHovering ? 0.15 : 0.1))
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
            Image(systemName: isPressed ? "arrow.down.to.line.square.fill" : "arrow.down.to.line.square")
                .font(.system(size: 16))
                .foregroundStyle(Color(red: 0.0, green: 0.5, blue: 0.0))
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color(red: 0.0, green: 0.5, blue: 0.0).opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
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
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

struct FileRow: View {
    let url: URL
    let onRemove: () -> Void
    @State private var isHoveringRow = false
    @State private var isHoveringButton = false
    @State private var isPressed = false
    
    var body: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 32, height: 32)
            
            Text(url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            if isHoveringRow {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: isPressed ? "xmark.square.fill" : "xmark.square")
                        .font(.system(size: 16))
                        .foregroundStyle(.red)
                        .padding(4)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(isHoveringButton ? Color.red.opacity(0.1) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .onHover { hovering in
                    isHoveringButton = hovering
                }
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
                    // Action handled by Button
                } onPressingChanged: { pressing in
                    isPressed = pressing
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHoveringRow)
        .onHover { hovering in
            isHoveringRow = hovering
        }
    }
}

struct ConvertedFileRow: View {
    let file: ConvertedFile
    let onSave: () -> Void
    @State private var isHoveringRow = false
    
    var body: some View {
        HStack {
            Image(nsImage: iconForFile(fileName: file.fileName))
                .resizable()
                .frame(width: 32, height: 32)
            
            Text(file.fileName)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            if isHoveringRow {
                SaveButton {
                    onSave()
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHoveringRow)
        .onHover { hovering in
            isHoveringRow = hovering
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

struct ConvertedFile: Identifiable {
    let id = UUID()
    let originalURL: URL
    let data: Data
    let fileName: String
}

struct SearchableFormatPicker: View {
    @Binding var selectedService: ConversionService
    let inputFileURLs: [URL]
    @State private var isExpanded = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var highlightedIndex: Int = 0
    
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
        
        // Detect if inputs are documents or images
        let documentFormats = inputFileURLs.compactMap { PandocFormat.detectFormat(from: $0) }
        let imageFormats = inputFileURLs.compactMap { ImageFormat.detectFormat(from: $0) }
        
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
    
    private var filteredServices: [(ConversionService, String)] {
        let services = compatibleServices
        if searchText.isEmpty {
            return services
        } else {
            return services.filter { $0.1.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            Button(action: {
                if !inputFileURLs.isEmpty {
                    isExpanded.toggle()
                    if isExpanded {
                        isSearchFocused = true
                    }
                }
            }) {
                HStack {
                    Text(inputFileURLs.isEmpty ? "Output Format" : getServiceDisplayName(selectedService))
                        .foregroundColor(inputFileURLs.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut(duration: 0.1), value: isExpanded)
                        .foregroundColor(inputFileURLs.isEmpty ? .secondary : .primary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(Color(NSColor.quaternaryLabelColor).opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .frame(width: 300)
            .zIndex(1)
            
            if isExpanded {
                VStack(spacing: 0) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("Search Formats", text: $searchText)
                            .textFieldStyle(.plain)
                            .focused($isSearchFocused)
                            .foregroundStyle(.primary)
                            .onSubmit {
                                if !filteredServices.isEmpty {
                                    selectedService = filteredServices[highlightedIndex].0
                                    isExpanded = false
                                    searchText = ""
                                }
                            }
                            .onChange(of: searchText) { _, _ in
                                highlightedIndex = 0
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                    .background(Color(NSColor.quaternaryLabelColor).opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredServices.enumerated()), id: \.element.0) { index, item in
                                let (service, name) = item
                                HStack {
                                    Text(name)
                                    Spacer()
                                    if servicesEqual(service, selectedService) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .background(
                                    highlightedIndex == index ? 
                                    Color.accentColor.opacity(0.2) :
                                    (servicesEqual(service, selectedService) ? Color.accentColor.opacity(0.1) : Color.clear)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedService = service
                                    isExpanded = false
                                    searchText = ""
                                }
                                .onHover { isHovered in
                                    if isHovered {
                                        highlightedIndex = index
                                    }
                                }
                                
                                if index != filteredServices.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .padding(.bottom, 8)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.blue, lineWidth: 1)
                )
                .cornerRadius(6)
                .shadow(radius: 4)
                .onKeyPress(.downArrow) {
                    if highlightedIndex < filteredServices.count - 1 {
                        highlightedIndex += 1
                    }
                    return .handled
                }
                .onKeyPress(.upArrow) {
                    if highlightedIndex > 0 {
                        highlightedIndex -= 1
                    }
                    return .handled
                }
                .onKeyPress(.return) {
                    if !filteredServices.isEmpty {
                        selectedService = filteredServices[highlightedIndex].0
                        isExpanded = false
                        searchText = ""
                    }
                    return .handled
                }
                .onKeyPress(.escape) {
                    isExpanded = false
                    searchText = ""
                    return .handled
                }
                .padding(.top, 44) // Height of the button
                .frame(width: 300)
                .zIndex(2)
            }
        }
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
    @State private var convertedFiles: [ConvertedFile] = []
    @State private var errorMessage: String?
    @State private var isTargeted = false
    
    @State private var pandocWrapper: PandocWrapper?
    @State private var pandocInitError: String?
    @State private var imageMagickWrapper: ImageMagickWrapper?
    @State private var imageMagickInitError: String?
    
    var body: some View {
        HStack(spacing: 0) {
            // Input pane
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
                            VStack(spacing: 12) {
                                let fileURL = inputFileURLs[0]
                                let isImage = ImageFormat.detectFormat(from: fileURL) != nil
                                
                                if isImage {
                                    AsyncImage(url: fileURL) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(maxWidth: 200, maxHeight: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: fileURL.path))
                                        .resizable()
                                        .frame(width: 64, height: 64)
                                }
                                
                                Text(fileURL.lastPathComponent)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                
                                ClearButton(
                                    label: "Clear",
                                    isDisabled: false
                                ) {
                                    inputFileURLs = []
                                    convertedFiles = []
                                    errorMessage = nil
                                }
                            }
                            .padding()
                        } else {
                            VStack(spacing: 0) {
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(inputFileURLs, id: \.self) { url in
                                            FileRow(
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
                                    .padding()
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
                SearchableFormatPicker(selectedService: $outputService, inputFileURLs: inputFileURLs)
                    .padding(.top)
                    .disabled(inputFileURLs.isEmpty)
                
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
            
            // Output pane
            VStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        )
                    
                    if isConverting {
                        ProgressView("Converting...")
                            .padding()
                    } else if !convertedFiles.isEmpty {
                        if convertedFiles.count == 1 {
                            VStack(spacing: 12) {
                                let file = convertedFiles[0]
                                let isImage = ImageFormat.detectFormat(from: URL(fileURLWithPath: file.fileName)) != nil
                                
                                if isImage {
                                    if let nsImage = NSImage(data: file.data) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: 200, maxHeight: 150)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    } else {
                                        Image(nsImage: iconForFile(fileName: file.fileName))
                                            .resizable()
                                            .frame(width: 64, height: 64)
                                    }
                                } else {
                                    Image(nsImage: iconForFile(fileName: file.fileName))
                                        .resizable()
                                        .frame(width: 64, height: 64)
                                }
                                
                                Text(file.fileName)
                                    .font(.headline)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                
                                SaveAllButton(
                                    label: "Save"
                                ) {
                                    saveFile(data: file.data, fileName: file.fileName)
                                }
                            }
                            .padding()
                        } else {
                            VStack(spacing: 0) {
                                ScrollView {
                                    VStack(spacing: 8) {
                                        ForEach(convertedFiles) { file in
                                            ConvertedFileRow(
                                                file: file,
                                                onSave: {
                                                    saveFile(data: file.data, fileName: file.fileName)
                                                }
                                            )
                                        }
                                    }
                                    .padding()
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
                            
                            Text("Converted Files")
                                .font(.headline)
                                .foregroundColor(.secondary)
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
                        let newImageFormat = ImageFormat.detectFormat(from: url)
                        
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
                        if (isNewDocument && hasExistingDocuments && !hasExistingImages) ||
                           (isNewImage && hasExistingImages && !hasExistingDocuments) {
                            self.inputFileURLs.append(url)
                            self.errorMessage = nil
                            self.updateOutputServiceToDefault()
                        } else {
                            // Get format names for error message
                            let newTypeName = isNewDocument ? "document" : "image"
                            let existingTypeName = hasExistingDocuments ? "document" : "image"
                            self.errorMessage = "Cannot mix different file types. You have \(existingTypeName) files, but tried to add a \(newTypeName) file."
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
            .image, .jpeg, .png, .gif, .bmp, .tiff,
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
                let newImageFormat = ImageFormat.detectFormat(from: url)
                
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
                if (isNewDocument && hasExistingDocuments && !hasExistingImages) ||
                   (isNewImage && hasExistingImages && !hasExistingDocuments) {
                    inputFileURLs.append(url)
                    updateOutputServiceToDefault()
                } else {
                    // Get format names for error message
                    let newTypeName = isNewDocument ? "document" : "image"
                    let existingTypeName = hasExistingDocuments ? "document" : "image"
                    errorMessage = "Cannot mix different file types. You have \(existingTypeName) files, but tried to add a \(newTypeName) file."
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
        
        for inputURL in inputFileURLs {
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
                case .imagemagick(let format):
                    try await imageMagickWrapper!.convertImage(
                        inputURL: inputURL,
                        outputURL: tempURL,
                        to: format
                    )
                }
                
                print("Conversion completed, reading result...")
                
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
    }
    
    private func saveFile(data: Data, fileName: String) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = fileName
        panel.allowedContentTypes = [UTType(filenameExtension: outputService.fileExtension)!]
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
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
                } catch {
                    errorMessage = "Failed to save \(file.fileName): \(error.localizedDescription)"
                    return
                }
            }
        }
    }
    
    private func iconForFile(fileName: String) -> NSImage {
        // Create a temporary file with the correct extension to get the proper icon
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Create an empty file if it doesn't exist
        if !FileManager.default.fileExists(atPath: tempURL.path) {
            FileManager.default.createFile(atPath: tempURL.path, contents: Data(), attributes: nil)
        }
        
        let icon = NSWorkspace.shared.icon(forFile: tempURL.path)
        
        // Clean up the temporary file
        try? FileManager.default.removeItem(at: tempURL)
        
        return icon
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
        let imageFormats = inputFileURLs.compactMap { ImageFormat.detectFormat(from: $0) }
        
        var compatibleServices: [(ConversionService, String)] = []
        
        if !documentFormats.isEmpty {
            // Document conversion with Pandoc
            var compatiblePandocFormats = Set(PandocFormat.compatibleOutputFormats(for: documentFormats[0]))
            for format in documentFormats.dropFirst() {
                compatiblePandocFormats.formIntersection(PandocFormat.compatibleOutputFormats(for: format))
            }
            compatibleServices.append(contentsOf: SearchableFormatPicker.documentFormats.filter { compatiblePandocFormats.contains($0.0) }.map { (.pandoc($0.0), $0.1) })
        }
        
        if !imageFormats.isEmpty {
            // Image conversion with ImageMagick
            let compatibleImageFormats = ImageFormat.outputFormats
            compatibleServices.append(contentsOf: SearchableFormatPicker.imageFormats.filter { compatibleImageFormats.contains($0.0) }.map { (.imagemagick($0.0), $0.1) })
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
