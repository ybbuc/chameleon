//
//  FilePreviewView.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
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
                        .overlay(
                            Rectangle()
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
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