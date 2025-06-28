//
//  FileContentRow.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ActivityIndicatorView
import ProgressIndicatorView

struct FileContentRow: View {
    let url: URL
    let onRemove: () -> Void
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
            Text(url.lastPathComponent)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Action buttons
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
            cachedIcon = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
}