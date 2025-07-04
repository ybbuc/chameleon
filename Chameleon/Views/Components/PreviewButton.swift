//
//  PreviewButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//

import SwiftUI

struct PreviewButton: View {
    let action: () -> Void
    var size: CGFloat = 16

    var body: some View {
        HoverButton(
            systemImage: "eye",
            helpText: "Quick Look",
            action: action,
            size: size
        )
    }
}
