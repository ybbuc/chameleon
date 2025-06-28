//
//  FileRow.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//

import SwiftUI
import AppKit

struct FileRow: View {
    let url: URL
    let onRemove: () -> Void
    @State private var isHoveringRow = false
    
    var body: some View {
        BaseFileRow(
            url: url,
            fileName: url.lastPathComponent,
            isHoveringRow: $isHoveringRow
        ) {
            // Content
            Text(url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
        } actions: {
            // Actions
            HStack(spacing: 4) {
                PreviewButton(action: {
                    QuickLookManager.shared.previewFile(at: url)
                })
                
                FinderButton(action: {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                })
                
                RemoveButton(action: onRemove)
            }
        }
        .background(isHoveringRow ? Color.secondary.opacity(0.05) : Color.clear)
    }
}
