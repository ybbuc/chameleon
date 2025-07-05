//
//  AppDelegate.swift
//  Chameleon
//
//  Created by Jakob Wells on 05.07.25.
//

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Check if a conversion is in progress
        if ConversionStateManager.shared.isConverting {
            // Show confirmation dialog
            let alert = NSAlert()
            alert.messageText = "Conversion in Progress"
            alert.informativeText = "A file conversion is currently in progress. Do you want to quit anyway?"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Quit Anyway")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                // User clicked "Cancel" - don't quit
                return .terminateCancel
            } else {
                // User clicked "Quit Anyway" - proceed with termination
                return .terminateNow
            }
        }
        
        // No conversion in progress, allow normal termination
        return .terminateNow
    }
}