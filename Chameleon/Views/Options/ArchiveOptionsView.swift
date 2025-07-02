//
//  ArchiveOptionsView.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import SwiftUI

struct ArchiveOptionsView: View {
    @Binding var archiveOptions: ArchiveOptions
    let fileCount: Int
    
    private var isToggleDisabled: Bool {
        return fileCount <= 1
    }
    
    var body: some View {
        Form {
            Toggle("Archive items separately", isOn: $archiveOptions.archiveSeparately)
                .disabled(isToggleDisabled)
                .onChange(of: archiveOptions.archiveSeparately) { _, newValue in
                    print("Archive separately changed to: \(newValue)")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
