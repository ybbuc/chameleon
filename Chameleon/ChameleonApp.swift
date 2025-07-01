//
//  ChameleonApp.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import SwiftUI
import SwiftData

@main
struct ChamelionApp: App {
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
