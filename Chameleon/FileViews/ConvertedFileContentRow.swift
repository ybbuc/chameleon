//
//  ConvertedFileContentRow.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ActivityIndicatorView
import ProgressIndicatorView

struct ConvertedFileContentRow: View {
    let file: ConvertedFile
    let onSave: () -> Void
    @State private var isHoveringRow = false
    @State private var cachedIcon: NSImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon
            if let icon = cachedIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 32, height: 32)
            }
            
            // File name
            Text(file.fileName)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Action buttons
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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHoveringRow ? Color.secondary.opacity(0.05) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringRow = hovering
            }
        }
        .onAppear {
            cachedIcon = iconForFile(fileName: file.fileName)
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