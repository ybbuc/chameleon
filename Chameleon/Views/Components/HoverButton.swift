//
//  HoverButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI

struct HoverButton: View {
    let systemImage: String
    let helpText: String
    let action: () -> Void
    var size: CGFloat = 16
    var color: Color = .secondary
    @State private var isHovering = false
    
    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size))
                .foregroundStyle(color)
                .padding(size >= 16 ? 8 : 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? color.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .help(helpText)
    }
}