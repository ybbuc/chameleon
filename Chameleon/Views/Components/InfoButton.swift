//
//  InfoButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI

struct InfoButton: View {
    let action: () -> Void
    var size: CGFloat = 16
    @State private var isHovering = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "info")
                .font(.system(size: size))
                .foregroundStyle(Color.secondary)
                .padding(size >= 16 ? 8 : 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.secondary.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Show media information")
    }
}