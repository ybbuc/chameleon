//
//  PreviewButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ActivityIndicatorView
import ProgressIndicatorView

struct PreviewButton: View {
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "eye")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.gray.opacity(0.2) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Quick Look")
    }
}