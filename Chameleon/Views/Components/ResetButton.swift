 //
//  ResetButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//

import SwiftUI

struct ResetButton: View {
    let label: String
    let isDisabled: Bool
    let action: () -> Void
    var size: CGFloat = 16
    
    var body: some View {
        HoverButton(
            systemImage: "arrow.uturn.backward",
            helpText: label,
            action: action,
            size: size
        )
        .disabled(isDisabled)
    }
}
