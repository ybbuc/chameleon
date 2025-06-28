//
//  ErrorFileRow.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI
import AppKit

struct ErrorFileRow: View {
    let url: URL
    let fileName: String
    let message: String
    let onRemove: () -> Void
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
            
            VStack(alignment: .leading) {
                Text(fileName)
                    .font(.headline)
                    .lineLimit(1)
                
                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
            Spacer()
            RemoveButton {
                onRemove()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            cachedIcon = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
}