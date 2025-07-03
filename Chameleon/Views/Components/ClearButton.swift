//
//  ClearButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import SwiftUI

struct ClearButton: View {
    let action: () -> Void
    var helpText: String = "Clear"
    var size: CGFloat = 16

    var body: some View {
        HoverButton(
            systemImage: "checkmark.circle.badge.xmark",
            helpText: helpText,
            action: action,
            size: size
        )
    }
}
