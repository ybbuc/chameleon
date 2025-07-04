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
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        // Initialize ProcessManager to set up termination handlers
        _ = ProcessManager.shared
    }
    
    var body: some Scene {
        Window("Chameleon", id: "main") {
            ContentView()
        }
        .modelContainer(for: [ConversionRecord.self])

        Settings {
            SettingsView()
        }
    }
}
