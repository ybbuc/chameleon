//
//  PandocWrapper.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import Foundation

class PandocWrapper {
    private let pandocPath: String
    private var currentProcess: Process?

    init() throws {
        // Use system pandoc from PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["pandoc"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus == 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                print("Found pandoc at: \(path)")
                self.pandocPath = path
                return
            }
        }

        // Fallback to common locations
        let commonPaths = [
            "/usr/local/bin/pandoc",
            "/opt/homebrew/bin/pandoc",
            "/opt/local/bin/pandoc"
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path) {
                print("Found pandoc at fallback location: \(path)")
                self.pandocPath = path
                return
            } else if FileManager.default.fileExists(atPath: path) {
                print("File exists but not executable: \(path)")
            }
        }

        throw PandocError.pandocNotInstalled
    }

    func convert(input: String, from inputFormat: PandocFormat, to outputFormat: PandocFormat) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pandocPath)

        let pipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = pipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        process.arguments = [
            "-f", inputFormat.rawValue,
            "-t", outputFormat.rawValue
        ]

        try process.run()

        // Write input to stdin
        if let inputData = input.data(using: .utf8) {
            pipe.fileHandleForWriting.write(inputData)
            pipe.fileHandleForWriting.closeFile()
        }

        // Wait for completion with cancellation support
        currentProcess = process
        defer { currentProcess = nil }

        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        // Read output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        if process.terminationStatus != 0 {
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw PandocError.conversionFailed(errorString)
        }

        guard let result = String(data: outputData, encoding: .utf8) else {
            throw PandocError.outputDecodingFailed
        }

        return result
    }

    func convertFile(inputURL: URL, outputURL: URL, from inputFormat: PandocFormat? = nil, to outputFormat: PandocFormat) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pandocPath)

        var arguments = [
            "-o", outputURL.path
        ]

        if let inputFormat = inputFormat {
            arguments.append(contentsOf: ["-f", inputFormat.rawValue])
        }

        arguments.append(contentsOf: ["-t", outputFormat.rawValue, inputURL.path])

        process.arguments = arguments

        // Ensure TeX is in PATH for PDF generation
        if outputFormat == .pdf {
            var environment = ProcessInfo.processInfo.environment
            let texPath = "/Library/TeX/texbin"
            if let currentPath = environment["PATH"] {
                environment["PATH"] = "\(texPath):\(currentPath)"
            } else {
                environment["PATH"] = texPath
            }
            process.environment = environment
        }

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()

        // Wait for completion with cancellation support
        currentProcess = process
        defer { currentProcess = nil }

        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"

            // Check for common LaTeX missing error
            if outputFormat == .pdf && (errorString.contains("pdflatex not found") ||
                                       errorString.contains("pdflatex: not found") ||
                                       errorString.contains("pdflatex: command not found") ||
                                       errorString.contains("Cannot find") ||
                                       errorString.contains("LaTeX Error")) {
                throw PandocError.latexNotInstalled
            }

            throw PandocError.conversionFailed(errorString)
        }
    }

    func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
    }
}

enum PandocFormat: String {
    // Common formats
    case markdown = "markdown"
    case html = "html"
    case latex = "latex"
    case pdf = "pdf"
    case docx = "docx"
    case rtf = "rtf"
    case epub = "epub"
    case plain = "plain"

    // Markdown variants
    case commonmark = "commonmark"
    case gfm = "gfm"
    case markdownStrict = "markdown_strict"
    case markdownPhpextra = "markdown_phpextra"
    case markdownMmd = "markdown_mmd"

    // Lightweight markup
    case rst = "rst"
    case asciidoc = "asciidoc"
    case textile = "textile"
    case org = "org"
    case muse = "muse"
    case creole = "creole"
    case djot = "djot"
    case markua = "markua"
    case txt2tags = "t2t"

    // Wiki formats
    case mediawiki = "mediawiki"
    case dokuwiki = "dokuwiki"
    case tikiwiki = "tikiwiki"
    case twiki = "twiki"
    case vimwiki = "vimwiki"
    case xwiki = "xwiki"
    case zimwiki = "zimwiki"
    case jira = "jira"

    // HTML variants
    case html4 = "html4"
    case html5 = "html5"
    case chunkedhtml = "chunkedhtml"

    // Ebook formats
    case epub2 = "epub2"
    case epub3 = "epub3"
    case fb2 = "fb2"

    // Documentation formats
    case man = "man"
    case ms = "ms"
    case mdoc = "mdoc"
    case texinfo = "texinfo"
    case haddock = "haddock"

    // XML formats
    case docbook = "docbook"
    case docbook4 = "docbook4"
    case docbook5 = "docbook5"
    case jats = "jats"
    case jatsArchiving = "jats_archiving"
    case jatsPublishing = "jats_publishing"
    case jatsArticleauthoring = "jats_articleauthoring"
    case bits = "bits"
    case tei = "tei"
    case opml = "opml"
    case opendocument = "opendocument"

    // Office formats
    case odt = "odt"
    case powerpoint = "pptx"
    case openoffice = "openoffice"

    // Academic formats
    case context = "context"
    case biblatex = "biblatex"
    case bibtex = "bibtex"
    case csljson = "csljson"
    case ris = "ris"
    case endnotexml = "endnotexml"

    // Presentation formats
    case beamer = "beamer"
    case slidy = "slidy"
    case slideous = "slideous"
    case dzslides = "dzslides"
    case revealjs = "revealjs"
    case s5 = "s5"

    // Other formats
    case json = "json"
    case native = "native"
    case icml = "icml"
    case typst = "typst"
    case ipynb = "ipynb"
    case csv = "csv"
    case tsv = "tsv"
    case ansi = "ansi"

    var description: String? {
        switch self {
        // Common formats
        case .markdown: return nil // You can add descriptions here
        case .html: return nil
        case .latex: return nil
        case .pdf: return nil
        case .docx: return nil
        case .rtf: return nil
        case .epub: return nil
        case .plain: return nil

        // Markdown variants
        case .commonmark: return nil
        case .gfm: return nil
        case .markdownStrict: return nil
        case .markdownPhpextra: return nil
        case .markdownMmd: return nil

        // Lightweight markup
        case .rst: return nil
        case .asciidoc: return nil
        case .textile: return nil
        case .org: return nil
        case .muse: return nil
        case .creole: return nil
        case .djot: return nil
        case .markua: return nil
        case .txt2tags: return nil

        // Wiki formats
        case .mediawiki: return nil
        case .dokuwiki: return nil
        case .tikiwiki: return nil
        case .twiki: return nil
        case .vimwiki: return nil
        case .xwiki: return nil
        case .zimwiki: return nil
        case .jira: return nil

        // HTML variants
        case .html4: return nil
        case .html5: return nil
        case .chunkedhtml: return nil

        // Ebook formats
        case .epub2: return nil
        case .epub3: return nil
        case .fb2: return nil

        // Documentation formats
        case .man: return nil
        case .ms: return nil
        case .mdoc: return nil
        case .texinfo: return nil
        case .haddock: return nil

        // XML formats
        case .docbook: return nil
        case .docbook4: return nil
        case .docbook5: return nil
        case .jats: return nil
        case .jatsArchiving: return nil
        case .jatsPublishing: return nil
        case .jatsArticleauthoring: return nil
        case .bits: return nil
        case .tei: return nil
        case .opml: return nil
        case .opendocument: return nil

        // Office formats
        case .odt: return nil
        case .powerpoint: return nil
        case .openoffice: return nil

        // Academic formats
        case .context: return nil
        case .biblatex: return nil
        case .bibtex: return nil
        case .csljson: return nil
        case .ris: return nil
        case .endnotexml: return nil

        // Presentation formats
        case .beamer: return nil
        case .slidy: return nil
        case .slideous: return nil
        case .dzslides: return nil
        case .revealjs: return nil
        case .s5: return nil

        // Other formats
        case .json: return nil
        case .native: return nil
        case .icml: return nil
        case .typst: return nil
        case .ipynb: return nil
        case .csv: return nil
        case .tsv: return nil
        case .ansi: return nil
        }
    }

    var displayName: String {
        switch self {
        // Common formats
        case .markdown: return "Markdown"
        case .html: return "HTML"
        case .pdf: return "PDF"
        case .docx: return "Word Document (DOCX)"
        case .latex: return "LaTeX"
        case .plain: return "Plain Text"
        case .rtf: return "Rich Text Format (RTF)"
        case .epub: return "EPUB"

        // Markdown variants
        case .commonmark: return "CommonMark"
        case .gfm: return "GitHub Flavored Markdown"
        case .markdownStrict: return "Strict Markdown"
        case .markdownPhpextra: return "PHP Markdown Extra"
        case .markdownMmd: return "MultiMarkdown"

        // Lightweight markup
        case .rst: return "reStructuredText"
        case .asciidoc: return "AsciiDoc"
        case .textile: return "Textile"
        case .org: return "Org Mode"
        case .muse: return "Emacs Muse"
        case .creole: return "Creole"
        case .djot: return "Djot"
        case .markua: return "Markua"
        case .txt2tags: return "txt2tags"

        // Wiki formats
        case .mediawiki: return "MediaWiki"
        case .dokuwiki: return "DokuWiki"
        case .tikiwiki: return "TikiWiki"
        case .twiki: return "TWiki"
        case .vimwiki: return "Vimwiki"
        case .xwiki: return "XWiki"
        case .zimwiki: return "ZimWiki"
        case .jira: return "Jira Wiki"

        // HTML variants
        case .html4: return "HTML 4"
        case .html5: return "HTML 5"
        case .chunkedhtml: return "Chunked HTML"

        // Ebook formats
        case .epub2: return "EPUB 2"
        case .epub3: return "EPUB 3"
        case .fb2: return "FictionBook2"

        // Documentation formats
        case .man: return "Man Page"
        case .ms: return "Roff ms"
        case .mdoc: return "mdoc"
        case .texinfo: return "GNU TexInfo"
        case .haddock: return "Haddock"

        // XML formats
        case .docbook: return "DocBook"
        case .docbook4: return "DocBook 4"
        case .docbook5: return "DocBook 5"
        case .jats: return "JATS"
        case .jatsArchiving: return "JATS Archiving"
        case .jatsPublishing: return "JATS Publishing"
        case .jatsArticleauthoring: return "JATS Article Authoring"
        case .bits: return "BITS"
        case .tei: return "TEI Simple"
        case .opml: return "OPML"
        case .opendocument: return "OpenDocument XML"

        // Office formats
        case .odt: return "OpenDocument Text (ODT)"
        case .powerpoint: return "PowerPoint (PPTX)"
        case .openoffice: return "OpenOffice"

        // Academic formats
        case .context: return "ConTeXt"
        case .biblatex: return "BibLaTeX"
        case .bibtex: return "BibTeX"
        case .csljson: return "CSL JSON"
        case .ris: return "RIS"
        case .endnotexml: return "EndNote XML"

        // Presentation formats
        case .beamer: return "LaTeX Beamer"
        case .slidy: return "Slidy"
        case .slideous: return "Slideous"
        case .dzslides: return "DZSlides"
        case .revealjs: return "reveal.js"
        case .s5: return "S5"

        // Other formats
        case .json: return "JSON"
        case .native: return "Native"
        case .icml: return "InDesign ICML"
        case .typst: return "Typst"
        case .ipynb: return "Jupyter Notebook"
        case .csv: return "CSV"
        case .tsv: return "TSV"
        case .ansi: return "ANSI Terminal"
        }
    }
}

enum PandocError: LocalizedError {
    case pandocNotInstalled
    case conversionFailed(String)
    case outputDecodingFailed
    case latexNotInstalled

    var errorDescription: String? {
        switch self {
        case .pandocNotInstalled:
            return "Pandoc is not installed. Please install it via Homebrew: brew install pandoc"
        case .conversionFailed(let message):
            return "Pandoc conversion failed: \(message)"
        case .outputDecodingFailed:
            return "Failed to decode pandoc output"
        case .latexNotInstalled:
            return "PDF generation requires LaTeX. Please install BasicTeX or MacTeX from https://www.tug.org/mactex/"
        }
    }
}

extension PandocFormat {
    // Formats that can be read (input formats)
    static let inputFormats: Set<PandocFormat> = [
        .markdown, .commonmark, .gfm, .markdownStrict, .markdownPhpextra, .markdownMmd,
        .rst, .asciidoc, .textile, .org, .muse, .creole, .djot, .markua, .txt2tags,
        .mediawiki, .dokuwiki, .tikiwiki, .twiki, .vimwiki, .jira,
        .html, .html4, .html5,
        .epub, .epub2, .epub3, .fb2,
        .man, .ms, .mdoc, .texinfo, .haddock,
        .docbook, .docbook4, .docbook5, .jats, .jatsArchiving, .jatsPublishing,
        .jatsArticleauthoring, .bits, .tei, .opml, .opendocument,
        .latex, .context,
        .biblatex, .bibtex, .csljson, .ris, .endnotexml,
        .docx, .odt, .rtf,
        .ipynb, .typst,
        .csv, .tsv,
        .json, .native
    ]

    // Formats that can be written (output formats)
    static let outputFormats: Set<PandocFormat> = [
        .markdown, .commonmark, .gfm, .markdownStrict, .markdownPhpextra, .markdownMmd,
        .rst, .asciidoc, .markua,
        .mediawiki, .dokuwiki, .xwiki, .zimwiki, .jira,
        .html, .html4, .html5, .chunkedhtml,
        .epub, .epub2, .epub3, .fb2,
        .man, .ms, .texinfo,
        .docbook, .docbook4, .docbook5, .jats, .jatsArchiving, .jatsPublishing,
        .jatsArticleauthoring, .bits, .tei, .opendocument,
        .latex, .context, .beamer,
        .biblatex, .bibtex, .csljson,
        .docx, .odt, .rtf, .powerpoint,
        .ipynb, .typst,
        .plain, .json, .native,
        .pdf, .icml,
        .slidy, .slideous, .dzslides, .revealjs, .s5,
        .ansi
    ]

    // Get compatible output formats for a given input format
    static func compatibleOutputFormats(for inputFormat: PandocFormat) -> [PandocFormat] {
        // All input formats can generally be converted to all output formats
        // with some exceptions
        var compatible = Array(outputFormats)

        // Special cases where certain conversions don't make sense
        switch inputFormat {
        case .csv, .tsv:
            // Tabular data has limited conversion options
            compatible = [.html, .html4, .html5, .latex, .markdown, .commonmark, .gfm,
                         .rst, .asciidoc, .mediawiki, .dokuwiki, .plain, .json]
        case .biblatex, .bibtex, .csljson, .ris, .endnotexml:
            // Bibliography formats have limited conversion options
            compatible = [.html, .html4, .html5, .latex, .markdown, .commonmark, .gfm,
                         .biblatex, .bibtex, .csljson, .plain, .json]
        default:
            break
        }

        return compatible.sorted { $0.rawValue < $1.rawValue }
    }

    // Detect format from file extension
    static func detectFormat(from url: URL) -> PandocFormat? {
        let ext = url.pathExtension.lowercased()
        return Self.extensionToFormatMap[ext]
    }
    
    private static let extensionToFormatMap: [String: PandocFormat] = [
        "md": .markdown, "markdown": .markdown,
        "html": .html, "htm": .html,
        "tex": .latex,
        "docx": .docx,
        "odt": .odt,
        "rtf": .rtf,
        "epub": .epub,
        "txt": .plain, "text": .plain,
        "rst": .rst,
        "adoc": .asciidoc, "asciidoc": .asciidoc,
        "textile": .textile,
        "org": .org,
        "wiki": .mediawiki,
        "texi": .texinfo, "texinfo": .texinfo,
        "xml": .docbook,
        "json": .json,
        "csv": .csv,
        "tsv": .tsv,
        "ipynb": .ipynb,
        "typ": .typst,
        "bib": .bibtex,
        "fb2": .fb2,
        "opml": .opml,
        "man": .man,
        "ms": .ms,
        "t2t": .txt2tags
        // Note: PDFs are treated as image format, not document format, so not included
    ]
}
