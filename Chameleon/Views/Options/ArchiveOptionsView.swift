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

    private var compressionDescription: String {
        switch archiveOptions.compressionLevel {
        case .fastest:
            return "Minimal compression, fastest processing"
        case .fast:
            return "Light compression, fast processing"
        case .normal:
            return "Balanced compression and speed"
        case .better:
            return "Good compression, slower processing"
        case .best:
            return "Maximum compression, slowest processing"
        }
    }

    var body: some View {
        Form {
            // Compression level at the top
            Picker("Compression:", selection: $archiveOptions.compressionLevel) {
                ForEach(CompressionLevel.allCases, id: \.self) { level in
                    Text(level.rawValue).tag(level)
                }
            }
            .pickerStyle(.menu)
            .transition(.opacity.combined(with: .move(edge: .top)))

            VStack(alignment: .leading, spacing: 4) {
                Text(compressionDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))

            Toggle("Archive items separately", isOn: $archiveOptions.archiveSeparately)
                .disabled(isToggleDisabled)
                .onChange(of: archiveOptions.archiveSeparately) { _, newValue in
                    print("Archive separately changed to: \(newValue)")
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

            if isToggleDisabled {
                Text("Multiple files required for separate archiving")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Toggle("Verify compression integrity", isOn: $archiveOptions.verifyAfterCreation)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}
