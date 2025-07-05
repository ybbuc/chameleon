//
//  TempFileManager.swift
//  Chameleon
//
//  Created by Jakob Wells on 05.07.25.
//

import Foundation

/// Manages temporary file creation and cleanup for the conversion process
final class TempFileManager {
    static let shared = TempFileManager()
    
    private var activeTempFiles: Set<URL> = []
    private let queue = DispatchQueue(label: "com.chameleon.tempfiles", attributes: .concurrent)
    
    private init() {}
    
    /// Creates a temporary directory and tracks it for cleanup
    func createTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        do {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            
            queue.async(flags: .barrier) {
                self.activeTempFiles.insert(url)
            }
        } catch {
            print("Failed to create temp directory: \(error)")
        }
        
        return url
    }
    
    /// Creates a temporary file with the given extension
    func createTempFile(extension fileExtension: String) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        
        queue.async(flags: .barrier) {
            self.activeTempFiles.insert(url)
        }
        
        return url
    }
    
    /// Creates a temporary file in a new directory with a specific filename
    func createTempFile(withName fileName: String) -> URL {
        let directory = createTempDirectory()
        return directory.appendingPathComponent(fileName)
    }
    
    /// Removes all tracked temporary files
    func cleanup() {
        let filesToRemove = queue.sync { activeTempFiles }
        
        for url in filesToRemove {
            do {
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            } catch {
                print("Failed to remove temp file at \(url.path): \(error)")
            }
        }
        
        queue.async(flags: .barrier) {
            self.activeTempFiles.removeAll()
        }
    }
    
    /// Removes a specific temporary file and stops tracking it
    func remove(_ url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            print("Failed to remove temp file at \(url.path): \(error)")
        }
        
        queue.async(flags: .barrier) {
            self.activeTempFiles.remove(url)
            // Also remove parent directory if it was tracked
            self.activeTempFiles.remove(url.deletingLastPathComponent())
        }
    }
    
    /// Marks a URL as no longer needing cleanup (e.g., after successful save)
    func untrack(_ url: URL) {
        queue.async(flags: .barrier) {
            self.activeTempFiles.remove(url)
            self.activeTempFiles.remove(url.deletingLastPathComponent())
        }
    }
    
    /// Returns the count of active temp files (for debugging)
    var activeFileCount: Int {
        queue.sync { activeTempFiles.count }
    }
    
    deinit {
        cleanup()
    }
}