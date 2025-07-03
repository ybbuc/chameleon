//
//  SaveButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//

import SwiftUI

struct SaveButton: View {
    let action: () -> Void
    var helpText: String = "Save"
    var size: CGFloat = 16

    var body: some View {
        HoverButton(
            systemImage: "arrow.down.to.line.compact",
            helpText: helpText,
            action: action,
            size: size,
            color: Color(red: 0.0, green: 0.5, blue: 0.0)
        )
    }
}
