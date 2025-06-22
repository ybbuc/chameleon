//
//  PandocWrapper.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import Foundation

class PandocWrapper {
    private let pandocPath: String
    
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
        
        // Wait for completion
        process.waitUntilExit()
        
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
        process.waitUntilExit()
        
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
        
        switch ext {
        case "md", "markdown":
            return .markdown
        case "html", "htm":
            return .html
        case "tex":
            return .latex
        case "pdf":
            return .pdf
        case "docx":
            return .docx
        case "odt":
            return .odt
        case "rtf":
            return .rtf
        case "epub":
            return .epub
        case "txt", "text":
            return .plain
        case "rst":
            return .rst
        case "adoc", "asciidoc":
            return .asciidoc
        case "textile":
            return .textile
        case "org":
            return .org
        case "wiki":
            return .mediawiki
        case "texi", "texinfo":
            return .texinfo
        case "xml":
            return .docbook
        case "json":
            return .json
        case "csv":
            return .csv
        case "tsv":
            return .tsv
        case "ipynb":
            return .ipynb
        case "typ":
            return .typst
        case "bib":
            return .bibtex
        case "fb2":
            return .fb2
        case "opml":
            return .opml
        case "man":
            return .man
        case "ms":
            return .ms
        case "t2t":
            return .txt2tags
        default:
            return nil
        }
    }
}