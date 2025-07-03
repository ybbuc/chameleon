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
    @State private var isHoveringRow = false

    var body: some View {
        BaseFileRow(
            url: url,
            fileName: fileName,
            isHoveringRow: $isHoveringRow
        ) {
            // Content
            VStack(alignment: .leading) {
                Text(fileName)
                    .lineLimit(1)

                Text(message)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(1)
            }
        } actions: {
            // Actions
            HStack(spacing: 4) {
                FinderButton(action: {
                    NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                }, size: 14)

                RemoveButton(action: onRemove, size: 14)
            }
        }
    }
}
