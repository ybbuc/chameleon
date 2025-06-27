//
//  FormatPicker.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ActivityIndicatorView
import ProgressIndicatorView

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