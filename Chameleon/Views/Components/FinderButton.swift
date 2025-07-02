//
//  FinderButton.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI

struct FinderButton: View {
    let action: () -> Void
    var size: CGFloat = 16
    
    var body: some View {
        HoverButton(
            systemImage: "folder",
            helpText: "Show in Finder",
            action: action,
            size: size
        )
    }
}
