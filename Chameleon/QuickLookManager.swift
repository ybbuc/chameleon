//
//  QuickLookSupport.swift
//  Chameleon
//
//  Created by Jakob Wells on 22.06.25.
//

import SwiftUI
import Quartz
import AppKit

// MARK: - Quick Look Button

struct QuickLookButton: View {
    let action: () -> Void
    var iconSize: CGFloat = 16
    var style: ButtonStyle = .compact
    @State private var isHovering = false
    @State private var isPressed = false
    
    enum ButtonStyle {
        case compact
        case full
    }
    
    var body: some View {
        Button {
            action()
        } label: {
            switch style {
            case .compact:
                Image(systemName: isPressed ? "eye.fill" : "eye")
                    .font(.system(size: iconSize))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .contentShape(Rectangle())
            case .full:
                Label("Preview", systemImage: isPressed ? "eye.fill" : "eye")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .background(isHovering ? Color.gray.opacity(0.2) : Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .onHover { hovering in
            isHovering = hovering
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity) {
            // Action handled by Button
        } onPressingChanged: { pressing in
            isPressed = pressing
        }
        .help("Quick Look")
    }
}

// MARK: - Quick Look Support for Temporary Data

class QuickLookPreviewController: NSViewController, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    var currentURL: URL?
    
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = self
        panel.delegate = self
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.dataSource = nil
        panel.delegate = nil
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return currentURL != nil ? 1 : 0
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return currentURL as NSURL?
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        if event.type == .keyDown && event.keyCode == 49 { // Space bar
            panel.close()
            return true
        }
        return false
    }
}

class QuickLookManager: ObservableObject {
    static let shared = QuickLookManager()
    private let previewController = QuickLookPreviewController()
    
    private init() {
        // Ensure the controller has a view
        previewController.view = NSView()
    }
    
    func previewFile(data: Data, fileName: String) {
        // Create a temporary file for preview
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            // Write data to temporary file
            try data.write(to: tempURL)
            
            // Set up the preview with temporary URL
            if let panel = QLPreviewPanel.shared() {
                // Set the URL in our controller
                previewController.currentURL = tempURL
                
                // Make our controller the current controller
                if let window = NSApp.keyWindow {
                    window.makeFirstResponder(previewController)
                }
                
                panel.updateController()
                
                // Open Quick Look if not already visible
                if !panel.isVisible {
                    panel.makeKeyAndOrderFront(nil)
                    panel.center()
                }
                
                panel.reloadData()
            }
            
            // Clean up temporary file after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 60) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            
        } catch {
            print("Error creating temporary file for Quick Look: \(error)")
        }
    }
    
    func previewFile(at url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("File does not exist at path: \(url.path)")
            return
        }
        
        // Set up the preview first
        if let panel = QLPreviewPanel.shared() {
            // Set the URL in our controller
            previewController.currentURL = url
            
            // Make our controller the current controller
            if let window = NSApp.keyWindow {
                window.makeFirstResponder(previewController)
            }
            
            panel.updateController()
            
            // Open Quick Look if not already visible
            if !panel.isVisible {
                panel.makeKeyAndOrderFront(nil)
                panel.center()
            }
            
            panel.reloadData()
        }
    }
}

