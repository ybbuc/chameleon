//
//  ConvertingFileRow.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI
import AppKit
import ActivityIndicatorView

struct ConvertingFileRow: View {
    let url: URL
    let fileName: String
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
                
                HStack(spacing: 4) {
                    ActivityIndicatorView(isVisible: .constant(true), type: .scalingDots(count: 3, inset: 4))
                        .frame(width: 20, height: 20)
                        .foregroundStyle(.blue)
                    Text("Converting...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onAppear {
            cachedIcon = NSWorkspace.shared.icon(forFile: url.path)
        }
    }
}