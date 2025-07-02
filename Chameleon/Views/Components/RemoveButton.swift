//
//  RemoveButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 27.06.25.
//


import SwiftUI

struct RemoveButton: View {
    let action: () -> Void
    var size: CGFloat = 16
    
    var body: some View {
        HoverButton(
            systemImage: "xmark",
            helpText: "Remove",
            action: action,
            size: size,
            color: .secondary
        )
    }
}
