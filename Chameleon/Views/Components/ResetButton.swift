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
    
    var body: some View {
        StandardButton(
            label: label,
            icon: "arrow.clockwise",
            isDisabled: isDisabled,
            action: action
        )
    }
}
