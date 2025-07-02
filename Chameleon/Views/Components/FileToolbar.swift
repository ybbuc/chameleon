//
//  FileToolbar.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import SwiftUI

struct FileToolbar: View {
    @Binding var files: [FileState]
    let onReset: () -> Void
    let onClearConverted: () -> Void
    let onSaveAll: () -> Void
    let onSave: (ConvertedFile) -> Void
    let onUpdateOutputService: () -> Void
    var onClear: (() -> Void)? = nil
    
    private var hasResettableFiles: Bool {
        files.contains { fileState in
            switch fileState {
            case .converted, .error:
                return true
            default:
                return false
            }
        }
    }
    
    private var convertedCount: Int {
        files.filter { if case .converted = $0 { true } else { false } }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal)
            
            if files.count == 1, let fileState = files.first {
                // Single file toolbar
                HStack(spacing: 12) {
                    switch fileState {
                    case .input(let url):
                        ResetButton(
                            label: "Reset",
                            isDisabled: true,
                            action: onReset
                        )
                        
                        PreviewButton(action: {
                            QuickLookManager.shared.previewFile(at: url)
                        })
                        
                        FinderButton(action: {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        })
                        
                        HoverButton(
                            systemImage: "xmark",
                            helpText: "Clear",
                            action: {
                                if let onClear = onClear {
                                    onClear()
                                } else {
                                    files = []
                                }
                                onUpdateOutputService()
                            }
                        )
                        
                    case .converting(let url, _):
                        FinderButton(action: {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        })
                        
                    case .converted(let convertedFile):
                        ResetButton(
                            label: "Reset",
                            isDisabled: false,
                            action: onReset
                        )
                        
                        PreviewButton(action: {
                            QuickLookManager.shared.previewFile(at: convertedFile.tempURL)
                        })
                        
                        SaveButton(
                            action: {
                                onSave(convertedFile)
                            }
                        )
                        
                        RemoveButton(
                            action: onClearConverted
                        )
                        
                    case .error(let url, _):
                        ResetButton(
                            label: "Reset",
                            isDisabled: false,
                            action: onReset
                        )
                        
                        FinderButton(action: {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        })
                        
                        HoverButton(
                            systemImage: "xmark",
                            helpText: "Clear",
                            action: {
                                if let onClear = onClear {
                                    onClear()
                                } else {
                                    files = []
                                }
                                onUpdateOutputService()
                            }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else {
                // Multiple files toolbar
                HStack(spacing: 12) {
                    ResetButton(
                        label: "Reset",
                        isDisabled: !hasResettableFiles,
                        action: onReset
                    )
                    
                    if convertedCount > 0 {
                        ClearButton(
                            action: onClearConverted,
                            helpText: "Clear all converted files"
                        )
                        
                        SaveButton(
                            action: onSaveAll,
                            helpText: convertedCount == 1 ? "Save" : "Save All"
                        )
                    }
                }
                .padding(.horizontal)
                .frame(height: 50)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Single file preview
        FileToolbar(
            files: .constant([.input(URL(fileURLWithPath: "/test.txt"))]),
            onReset: {},
            onClearConverted: {},
            onSaveAll: {},
            onSave: { _ in },
            onUpdateOutputService: {}
        )
        
        // Multiple files preview
        FileToolbar(
            files: .constant([
                .input(URL(fileURLWithPath: "/test.txt")),
                .converted(ConvertedFile(
                    originalURL: URL(fileURLWithPath: "/test.txt"),
                    tempURL: URL(fileURLWithPath: "/test.mp3"),
                    fileName: "test.mp3"
                ))
            ]),
            onReset: {},
            onClearConverted: {},
            onSaveAll: {},
            onSave: { _ in },
            onUpdateOutputService: {}
        )
    }
    .frame(width: 400)
}