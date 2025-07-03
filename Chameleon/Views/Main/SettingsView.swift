//
//  SettingsView.swift
//  Chameleon
//
//  Created by Jakob Wells on 01.07.25.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("saveToSourceFolder") private var saveToSourceFolder: Bool = false
    @AppStorage("playSounds") private var playSounds: Bool = true
    @AppStorage("autoClearMissingFiles") private var autoClearMissingFiles: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Save to source folder", isOn: $saveToSourceFolder)
                    .help("Automatically save converted files to the same folder as the original files")

                Toggle("Automatically clear missing files", isOn: $autoClearMissingFiles)
                    .help("Remove saved history entries for files that no longer exist")
            } header: {
                Text("File Management")
            }

            Section {
                Toggle("Play sounds", isOn: $playSounds)
                    .help("Play completion and error sounds during file conversion")
            } header: {
                Text("Sound")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 240)
        .fixedSize()
    }
}

#Preview {
    SettingsView()
}
