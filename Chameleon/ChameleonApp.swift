//
//  ChameleonApp.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import SwiftUI
import SwiftData

@main
struct ChameleonApp: App {
    init() {
        // Initialize ProcessManager to set up termination handlers
        _ = ProcessManager.shared
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ConversionRecord.self])

        Settings {
            SettingsView()
        }
    }
}
