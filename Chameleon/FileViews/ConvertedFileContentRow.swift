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
        HStack {
            Text(file.fileName)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
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
        .frame(height: 32)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringRow = hovering
            }
        }
    }
}