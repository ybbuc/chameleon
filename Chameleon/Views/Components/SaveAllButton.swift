//
//  SaveAllButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ActivityIndicatorView
import ProgressIndicatorView

struct SaveAllButton: View {
    let label: String
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Label(label, systemImage: "arrow.down.to.line.compact")
                .font(.body)
                .foregroundStyle(Color(red: 0.0, green: 0.5, blue: 0.0))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(red: 0.0, green: 0.5, blue: 0.0).opacity(isHovering ? 0.15 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}