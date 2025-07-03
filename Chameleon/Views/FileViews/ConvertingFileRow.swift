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
    @State private var isHoveringRow = false

    var body: some View {
        BaseFileRow(
            url: url,
            fileName: fileName,
            isHoveringRow: $isHoveringRow,
            overlay: AnyView(
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        ActivityIndicatorView(isVisible: .constant(true), type: .scalingDots(count: 3, inset: 4))
                            .frame(width: 40, height: 20)
                            .foregroundStyle(.white)
                    )
            ),
            backgroundColor: Color.gray.opacity(0.05)
        ) {
            // Content
            Text(fileName)
                .lineLimit(1)
        } actions: {
            // No actions for converting state
            EmptyView()
        }
    }
}
