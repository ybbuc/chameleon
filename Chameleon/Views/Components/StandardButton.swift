//
//  StandardButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI

struct StandardButton: View {
    let label: String?
    let icon: String
    let foregroundColor: Color
    let backgroundColor: Color
    let isDisabled: Bool
    let action: () -> Void
    @State private var isHovering = false
    @State private var isPressed = false
    
    init(
        label: String? = nil,
        icon: String,
        foregroundColor: Color = .secondary,
        backgroundColor: Color = Color.gray.opacity(0.1),
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.label = label
        self.icon = icon
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            Group {
                if let label = label {
                    Label(label, systemImage: icon)
                        .font(.body)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13))
                }
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, label != nil ? 16 : 6)
            .padding(.vertical, label != nil ? 8 : 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.gray.opacity(0.2) : backgroundColor)
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
        .disabled(isDisabled)
    }
}