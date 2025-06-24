//
//  ChameleonApp.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import SwiftUI

@main
struct ChamelionApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    if !hasCompletedOnboarding {
                        showOnboarding = true
                    }
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(showOnboarding: $showOnboarding)
                        .onDisappear {
                            hasCompletedOnboarding = true
                        }
                }
        }
        .commands {
            CommandGroup(after: .help) {
                Button("Setup Dependencies...") {
                    showOnboarding = true
                }
                .keyboardShortcut("?", modifiers: [.command, .shift])
            }
        }
    }
}
