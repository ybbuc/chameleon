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
    
    var body: some View {
        BaseFileRow(
            url: nil,
            fileName: file.fileName,
            customIcon: iconForFile(fileName: file.fileName),
            isHoveringRow: $isHoveringRow
        ) {
            // Content
            Text(file.fileName)
                .lineLimit(1)
                .truncationMode(.middle)
        } actions: {
            // Actions
            HStack(spacing: 4) {
                if isHoveringRow {
                    PreviewButton(action: {
                        QuickLookManager.shared.previewFile(at: file.tempURL)
                    })
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
                
                SaveButton {
                    onSave()
                }
            }
        }
        .background(isHoveringRow ? Color.secondary.opacity(0.05) : Color.clear)
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