//
//  ArchiveService.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import Foundation
import System

enum TarCompressionType {
    case none
    case gzip
    case bzip2
    case xz
    
    var tarFlag: String {
        switch self {
        case .none:
            return "-cf"
        case .gzip:
            return "-czf"
        case .bzip2:
            return "-cjf"
        case .xz:
            return "-cJf"
        }
    }
}

class ArchiveService {
    
    func createArchive(format: ArchiveFormat, from files: [URL], outputURL: URL, separately: Bool = false) async throws -> [URL] {
        if separately {
            return try await createArchivesSeparately(format: format, from: files, outputDirectory: outputURL.deletingLastPathComponent())
        } else {
            try await createSingleArchive(format: format, from: files, outputURL: outputURL)
            return [outputURL]
        }
    }
    
    private func createSingleArchive(format: ArchiveFormat, from files: [URL], outputURL: URL) async throws {
        switch format {
        case .zip:
            try await createZipArchive(from: files, outputURL: outputURL)
        case .tar:
            try await createTarArchive(from: files, outputURL: outputURL, compressionType: .none)
        case .tarGz:
            try await createTarArchive(from: files, outputURL: outputURL, compressionType: .gzip)
        case .tarXz:
            try await createTarArchive(from: files, outputURL: outputURL, compressionType: .xz)
        case .tarBz2:
            try await createTarArchive(from: files, outputURL: outputURL, compressionType: .bzip2)
        }
    }
    
    private func createArchivesSeparately(format: ArchiveFormat, from files: [URL], outputDirectory: URL) async throws -> [URL] {
        var createdArchives: [URL] = []
        
        for file in files {
            let fileName = file.deletingPathExtension().lastPathComponent
            let archiveURL = outputDirectory
                .appendingPathComponent("\(fileName).\(format.fileExtension)")
            
            try await createSingleArchive(format: format, from: [file], outputURL: archiveURL)
            createdArchives.append(archiveURL)
        }
        
        return createdArchives
    }
    
    private func createZipArchive(from files: [URL], outputURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        
        var arguments = ["-r", outputURL.path]
        
        // Add all input files
        for file in files {
            arguments.append(file.path)
        }
        
        process.arguments = arguments
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        
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
            throw ArchiveError.zipCreationFailed(errorString)
        }
    }
    
    private func createTarArchive(from files: [URL], outputURL: URL, compressionType: TarCompressionType) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        
        var arguments: [String] = []
        
        arguments.append(compressionType.tarFlag)
        arguments.append(outputURL.path)
        
        // Add all input files
        for file in files {
            arguments.append(file.path)
        }
        
        process.arguments = arguments
        
        let errorPipe = Pipe()
        process.standardError = errorPipe
        
        try process.run()
        
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
            throw ArchiveError.tarCreationFailed(errorString)
        }
    }
}

enum ArchiveFormat: String, CaseIterable {
    case zip = "zip"
    case tar = "tar"
    case tarGz = "tar.gz"
    case tarXz = "tar.xz"
    case tarBz2 = "tar.bz2"
    
    var displayName: String {
        switch self {
        case .zip:
            return "ZIP"
        case .tar:
            return "TAR"
        case .tarGz:
            return "TAR.GZ"
        case .tarXz:
            return "TAR.XZ"
        case .tarBz2:
            return "TAR.BZ2"
        }
    }
    
    var description: String {
        switch self {
        case .zip:
            return "Create a compressed ZIP archive containing all selected files."
        case .tar:
            return "Create an uncompressed TAR archive containing all selected files."
        case .tarGz:
            return "Create a gzip-compressed TAR archive containing all selected files."
        case .tarXz:
            return "Create an xz-compressed TAR archive containing all selected files."
        case .tarBz2:
            return "Create a bzip2-compressed TAR archive containing all selected files."
        }
    }
    
    var fileExtension: String {
        return rawValue
    }
}

enum ArchiveError: LocalizedError {
    case zipCreationFailed(String)
    case tarCreationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .zipCreationFailed(let message):
            return "ZIP creation failed: \(message)"
        case .tarCreationFailed(let message):
            return "TAR creation failed: \(message)"
        }
    }
}
