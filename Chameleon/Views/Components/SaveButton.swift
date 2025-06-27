//
//  SaveButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


import SwiftUI
import UniformTypeIdentifiers
import AppKit
import ActivityIndicatorView
import ProgressIndicatorView

struct SaveButton: View {
    let action: () -> Void
    @State private var isHovering = false
    @State private var isPressed = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "arrow.down.to.line.compact")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.0, green: 0.5, blue: 0.0))
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color(red: 0.0, green: 0.5, blue: 0.0).opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
            // Action handled by Button
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
    }
}