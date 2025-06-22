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

class QuickLookManager: ObservableObject {
    static let shared = QuickLookManager()
    
    private init() {}
    
    func previewFile(data: Data, fileName: String) {
        // Create a temporary file for preview
        let tempDirectory = FileManager.default.temporaryDirectory
        let tempURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            // Write data to temporary file
            try data.write(to: tempURL)
            
            // Open Quick Look
            if QLPreviewPanel.shared()?.isVisible ?? false {
                QLPreviewPanel.shared()?.close()
            }
            
            QLPreviewPanel.shared()?.makeKeyAndOrderFront(nil)
            QLPreviewPanel.shared()?.center()
            
            // Set up the preview with temporary URL
            if let panel = QLPreviewPanel.shared() {
                let coordinator = QuickLookCoordinator(url: tempURL)
                panel.dataSource = coordinator
                panel.delegate = coordinator
                panel.reloadData()
                
                // Keep the coordinator alive during preview
                objc_setAssociatedObject(panel, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
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
        
        // Open Quick Look
        if QLPreviewPanel.shared()?.isVisible ?? false {
            QLPreviewPanel.shared()?.close()
        }
        
        QLPreviewPanel.shared()?.makeKeyAndOrderFront(nil)
        QLPreviewPanel.shared()?.center()
        
        // Set up the preview
        if let panel = QLPreviewPanel.shared() {
            let coordinator = QuickLookCoordinator(url: url)
            panel.dataSource = coordinator
            panel.delegate = coordinator
            panel.reloadData()
            
            // Keep the coordinator alive during preview
            objc_setAssociatedObject(panel, "coordinator", coordinator, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

private class QuickLookCoordinator: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return 1
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return url as NSURL
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Handle key events (like space bar to close)
        if event.type == .keyDown {
            switch event.keyCode {
            case 49: // Space bar
                panel.close()
                return true
            default:
                break
            }
        }
        return false
    }
}