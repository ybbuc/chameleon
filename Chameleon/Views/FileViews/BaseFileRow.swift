//
//  BaseFileRow.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI
import AppKit

struct BaseFileRow<Content: View, Actions: View>: View {
    let url: URL?
    let fileName: String
    let customIcon: NSImage?
    let isHoveringRow: Binding<Bool>
    let overlay: AnyView?
    let backgroundColor: Color?
    @ViewBuilder let content: () -> Content
    @ViewBuilder let actions: () -> Actions
    
    @State private var cachedIcon: NSImage?
    
    init(
        url: URL?,
        fileName: String,
        customIcon: NSImage? = nil,
        isHoveringRow: Binding<Bool>,
        overlay: AnyView? = nil,
        backgroundColor: Color? = nil,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder actions: @escaping () -> Actions
    ) {
        self.url = url
        self.fileName = fileName
        self.customIcon = customIcon
        self.isHoveringRow = isHoveringRow
        self.overlay = overlay
        self.backgroundColor = backgroundColor
        self.content = content
        self.actions = actions
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Group {
                if let customIcon = customIcon {
                    Image(nsImage: customIcon)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else if let cachedIcon = cachedIcon {
                    Image(nsImage: cachedIcon)
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 32, height: 32)
                }
            }
            
            // Content area
            content()
            
            Spacer()
            
            // Actions area
            actions()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor ?? (isHoveringRow.wrappedValue ? Color.secondary.opacity(0.05) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            overlay
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHoveringRow.wrappedValue = hovering
            }
        }
        .onAppear {
            loadIcon()
        }
    }
    
    private func loadIcon() {
        guard let url = url, customIcon == nil else { return }
        cachedIcon = NSWorkspace.shared.icon(forFile: url.path)
    }
}