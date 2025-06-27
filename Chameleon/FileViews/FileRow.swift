//
//  FileRow.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ActivityIndicatorView
import ProgressIndicatorView

struct FileRow: View {
    let url: URL
    let onRemove: () -> Void
    @State private var isHoveringRow = false
    
    var body: some View {
        HStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: 32, height: 32)
                .fixedSize()
            
            Text(url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            HStack(spacing: 4) {
                if isHoveringRow {
                    PreviewButton(action: {
                        QuickLookManager.shared.previewFile(at: url)
                    })
                    .transition(.opacity)
                }
                
                RemoveButton(action: onRemove)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringRow = hovering
            }
        }
    }
}