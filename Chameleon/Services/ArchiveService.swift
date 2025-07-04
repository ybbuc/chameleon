//
//  ArchiveService.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import Foundation
import System
import Darwin

enum CompressionLevel: String, CaseIterable {
    case fastest = "Fastest"
    case fast = "Fast"
    case normal = "Normal"
    case better = "Better"
    case best = "Best"

    var zipLevel: String {
        switch self {
        case .fastest: return "-1"
        case .fast: return "-3"
        case .normal: return "-6"
        case .better: return "-7"
        case .best: return "-9"
        }
    }

    var gzipLevel: String {
        switch self {
        case .fastest: return "-1"
        case .fast: return "-3"
        case .normal: return "-6"
        case .better: return "-7"
        case .best: return "-9"
        }
    }

    var bzip2Level: String {
        switch self {
        case .fastest: return "-1"
        case .fast: return "-3"
        case .normal: return "-6"
        case .better: return "-7"
        case .best: return "-9"
        }
    }

    var xzLevel: String {
        switch self {
        case .fastest: return "-0"
        case .fast: return "-2"
        case .normal: return "-6"
        case .better: return "-7"
        case .best: return "-9"
        }
    }
}

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
    private var currentProcess: Process?

    func createArchive(format: ArchiveFormat, from files: [URL], outputURL: URL, separately: Bool = false, verifyAfterCreation: Bool = true, compressionLevel: CompressionLevel = .normal) async throws -> [URL] {
        if separately {
            return try await createArchivesSeparately(
                format: format,
                from: files,
                outputDirectory: outputURL.deletingLastPathComponent(),
                verifyAfterCreation: verifyAfterCreation,
                compressionLevel: compressionLevel
            )
        } else {
            try await createSingleArchive(format: format, from: files, outputURL: outputURL, compressionLevel: compressionLevel)

            if verifyAfterCreation {
                _ = try await verifyArchive(at: outputURL, format: format)
            }

            return [outputURL]
        }
    }

    private func createSingleArchive(format: ArchiveFormat, from files: [URL], outputURL: URL, compressionLevel: CompressionLevel = .normal) async throws {
        switch format {
        case .zip:
            try await createZipArchive(from: files, outputURL: outputURL, compressionLevel: compressionLevel)
        case .tar:
            try await createTarArchive(from: files, outputURL: outputURL, compressionType: .none, compressionLevel: compressionLevel)
        case .tarGz:
            try await createTarArchive(from: files, outputURL: outputURL, compressionType: .gzip, compressionLevel: compressionLevel)
        case .tarXz:
            try await createTarArchive(from: files, outputURL: outputURL, compressionType: .xz, compressionLevel: compressionLevel)
        case .tarBz2:
            try await createTarArchive(from: files, outputURL: outputURL, compressionType: .bzip2, compressionLevel: compressionLevel)
        }
    }

    private func createArchivesSeparately(format: ArchiveFormat, from files: [URL], outputDirectory: URL, verifyAfterCreation: Bool = true, compressionLevel: CompressionLevel = .normal) async throws -> [URL] {
        var createdArchives: [URL] = []

        for file in files {
            let fileName = file.deletingPathExtension().lastPathComponent
            let archiveURL = outputDirectory
                .appendingPathComponent("\(fileName).\(format.fileExtension)")

            try await createSingleArchive(
                format: format,
                from: [file],
                outputURL: archiveURL,
                compressionLevel: compressionLevel
            )

            if verifyAfterCreation {
                _ = try await verifyArchive(at: archiveURL, format: format)
            }

            createdArchives.append(archiveURL)
        }

        return createdArchives
    }

    private func createZipArchive(from files: [URL], outputURL: URL, compressionLevel: CompressionLevel = .normal) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")

        var arguments = [compressionLevel.zipLevel, "-r", outputURL.path]

        // Add all input files
        for file in files {
            arguments.append(file.path)
        }

        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        
        // Register with ProcessManager
        ProcessManager.shared.register(process)
        
        // Track for cancellation
        currentProcess = process
        defer {
            currentProcess = nil
            ProcessManager.shared.unregister(process)
        }

        while process.isRunning {
            if Task.isCancelled {
                // Send SIGINT for graceful shutdown
                let processID = process.processIdentifier
                if processID > 0 {
                    kill(processID, SIGINT)
                }
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

    private func createTarArchive(from files: [URL], outputURL: URL, compressionType: TarCompressionType, compressionLevel: CompressionLevel = .normal) async throws {
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

        // Set compression level via environment variables
        var environment = ProcessInfo.processInfo.environment
        switch compressionType {
        case .gzip:
            environment["GZIP"] = compressionLevel.gzipLevel
        case .bzip2:
            environment["BZIP2"] = compressionLevel.bzip2Level
        case .xz:
            environment["XZ_OPT"] = compressionLevel.xzLevel
        case .none:
            break // No compression level for uncompressed tar
        }
        process.environment = environment

        let errorPipe = Pipe()
        process.standardError = errorPipe

        try process.run()
        
        // Register with ProcessManager
        ProcessManager.shared.register(process)
        
        // Track for cancellation
        currentProcess = process
        defer {
            currentProcess = nil
            ProcessManager.shared.unregister(process)
        }

        while process.isRunning {
            if Task.isCancelled {
                // Send SIGINT for graceful shutdown
                let processID = process.processIdentifier
                if processID > 0 {
                    kill(processID, SIGINT)
                }
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

    // MARK: - Archive Verification

    func verifyArchive(at url: URL, format: ArchiveFormat) async throws -> Bool {
        switch format {
        case .zip:
            return try await verifyZipArchive(at: url)
        case .tar:
            return try await verifyTarArchive(at: url, compressionType: .none)
        case .tarGz:
            return try await verifyTarArchive(at: url, compressionType: .gzip)
        case .tarXz:
            return try await verifyTarArchive(at: url, compressionType: .xz)
        case .tarBz2:
            return try await verifyTarArchive(at: url, compressionType: .bzip2)
        }
    }

    private func verifyZipArchive(at url: URL) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-t", url.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        
        // Register with ProcessManager
        ProcessManager.shared.register(process)
        
        // Track for cancellation
        currentProcess = process
        defer {
            currentProcess = nil
            ProcessManager.shared.unregister(process)
        }

        while process.isRunning {
            if Task.isCancelled {
                // Send SIGINT for graceful shutdown
                let processID = process.processIdentifier
                if processID > 0 {
                    kill(processID, SIGINT)
                }
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.zipVerificationFailed(errorString)
        }

        return true
    }

    private func verifyTarArchive(at url: URL, compressionType: TarCompressionType) async throws -> Bool {
        switch compressionType {
        case .gzip:
            return try await verifyCompressionIntegrity(at: url, tool: "/usr/bin/gzip")
        case .bzip2:
            return try await verifyCompressionIntegrity(at: url, tool: "/usr/bin/bzip2")
        case .xz:
            return try await verifyCompressionIntegrity(at: url, tool: "/usr/bin/xz")
        case .none:
            return try await verifyTarContents(at: url, compressionFlag: "-tf")
        }
    }

    private func verifyCompressionIntegrity(at url: URL, tool: String) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = ["-t", url.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        
        // Register with ProcessManager
        ProcessManager.shared.register(process)
        
        // Track for cancellation
        currentProcess = process
        defer {
            currentProcess = nil
            ProcessManager.shared.unregister(process)
        }

        while process.isRunning {
            if Task.isCancelled {
                // Send SIGINT for graceful shutdown
                let processID = process.processIdentifier
                if processID > 0 {
                    kill(processID, SIGINT)
                }
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.compressionVerificationFailed(errorString)
        }

        return true
    }

    private func verifyTarContents(at url: URL, compressionFlag: String) async throws -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
        process.arguments = [compressionFlag, url.path]

        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        try process.run()
        
        // Register with ProcessManager
        ProcessManager.shared.register(process)
        
        // Track for cancellation
        currentProcess = process
        defer {
            currentProcess = nil
            ProcessManager.shared.unregister(process)
        }

        while process.isRunning {
            if Task.isCancelled {
                // Send SIGINT for graceful shutdown
                let processID = process.processIdentifier
                if processID > 0 {
                    kill(processID, SIGINT)
                }
                throw CancellationError()
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorString = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw ArchiveError.tarVerificationFailed(errorString)
        }

        return true
    }
    
    func cancel() {
        if let process = currentProcess {
            // Send SIGINT for graceful shutdown
            let processID = process.processIdentifier
            if processID > 0 {
                kill(processID, SIGINT)
            }
            currentProcess = nil
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
    case zipVerificationFailed(String)
    case tarVerificationFailed(String)
    case compressionVerificationFailed(String)

    var errorDescription: String? {
        switch self {
        case .zipCreationFailed(let message):
            return "ZIP creation failed: \(message)"
        case .tarCreationFailed(let message):
            return "TAR creation failed: \(message)"
        case .zipVerificationFailed(let message):
            return "ZIP verification failed: \(message)"
        case .tarVerificationFailed(let message):
            return "TAR verification failed: \(message)"
        case .compressionVerificationFailed(let message):
            return "Compression verification failed: \(message)"
        }
    }
}
