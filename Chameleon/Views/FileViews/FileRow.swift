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
    let isPDFMergeMode: Bool
    let index: Int
    let totalFiles: Int
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onRemove: () -> Void
    let mediaInfo: DetailedMediaInfo?
    @Binding var selectedSubtitles: Set<Int>
    @State private var isHoveringRow = false
    @State private var showingMediaInfo = false
    
    // Keep hover buttons visible when any popover is open
    private var shouldShowHoverButtons: Bool {
        isHoveringRow || showingMediaInfo
    }

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
                if isPDFMergeMode {
                    // Show up/down arrows for PDF merge mode (always visible)
                    HoverButton(
                        systemImage: "chevron.up",
                        helpText: "Move up",
                        action: onMoveUp,
                        size: 14
                    )
                    .disabled(index == 0)

                    HoverButton(
                        systemImage: "chevron.down",
                        helpText: "Move down",
                        action: onMoveDown,
                        size: 14
                    )
                    .disabled(index == totalFiles - 1)
                } else {
                    // Show hover buttons for normal mode
                    if shouldShowHoverButtons {
                        InfoButton(action: {
                            showingMediaInfo = true
                        }, size: 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        .popover(isPresented: $showingMediaInfo) {
                            MediaInfoView(url: url)
                        }
                        
                        PreviewButton(action: {
                            QuickLookManager.shared.previewFile(at: url)
                        }, size: 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))

                        FinderButton(action: {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        }, size: 14)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    }
                }

                RemoveButton(action: onRemove, size: 14)
            }
        }
    }
}
