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
    var onClear: (() -> Void)?
    let mediaInfoCache: [URL: DetailedMediaInfo]
    @State private var showingMediaInfo = false
    @State private var showingSubtitleSelection = false
    @State private var selectedSubtitles: Set<Int> = []

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
        VStack {
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
                        
                        // Show subtitle button for all video files (before info button)
                        if let mediaInfo = mediaInfoCache[url], mediaInfo.hasVideo {
                            SubtitleButton(action: {
                                showingSubtitleSelection = true
                            }, size: 16, hasSubtitles: mediaInfo.hasSubtitles)
                            .disabled(!mediaInfo.hasSubtitles)
                            .popover(isPresented: $showingSubtitleSelection) {
                                SubtitleSelectionView(
                                    subtitleStreams: mediaInfo.subtitleStreams,
                                    selectedSubtitles: $selectedSubtitles
                                )
                            }
                        }

                        InfoButton(action: {
                            showingMediaInfo = true
                        })
                        .popover(isPresented: $showingMediaInfo) {
                            MediaInfoView(url: url, cachedMediaInfo: mediaInfoCache[url])
                        }

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
                        // Show subtitle button for all video files (before info button)
                        if let mediaInfo = mediaInfoCache[url], mediaInfo.hasVideo {
                            SubtitleButton(action: {
                                showingSubtitleSelection = true
                            }, size: 16, hasSubtitles: mediaInfo.hasSubtitles)
                            .disabled(!mediaInfo.hasSubtitles)
                            .popover(isPresented: $showingSubtitleSelection) {
                                SubtitleSelectionView(
                                    subtitleStreams: mediaInfo.subtitleStreams,
                                    selectedSubtitles: $selectedSubtitles
                                )
                            }
                        }
                        
                        InfoButton(action: {
                            showingMediaInfo = true
                        })
                        .popover(isPresented: $showingMediaInfo) {
                            MediaInfoView(url: url, cachedMediaInfo: mediaInfoCache[url])
                        }
                        
                        FinderButton(action: {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
                        })

                    case .converted(let convertedFile):
                        ResetButton(
                            label: "Reset",
                            isDisabled: false,
                            action: onReset
                        )

                        InfoButton(action: {
                            showingMediaInfo = true
                        })
                        .popover(isPresented: $showingMediaInfo) {
                            MediaInfoView(url: convertedFile.tempURL, cachedMediaInfo: mediaInfoCache[convertedFile.originalURL])
                        }

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
                        
                        // Show subtitle button for all video files (before info button)
                        if let mediaInfo = mediaInfoCache[url], mediaInfo.hasVideo {
                            SubtitleButton(action: {
                                showingSubtitleSelection = true
                            }, size: 16, hasSubtitles: mediaInfo.hasSubtitles)
                            .disabled(!mediaInfo.hasSubtitles)
                            .popover(isPresented: $showingSubtitleSelection) {
                                SubtitleSelectionView(
                                    subtitleStreams: mediaInfo.subtitleStreams,
                                    selectedSubtitles: $selectedSubtitles
                                )
                            }
                        }

                        InfoButton(action: {
                            showingMediaInfo = true
                        })
                        .popover(isPresented: $showingMediaInfo) {
                            MediaInfoView(url: url, cachedMediaInfo: mediaInfoCache[url])
                        }

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
        .onAppear {
            // Initialize selected subtitles when single file view appears
            if files.count == 1, let fileState = files.first, let url = fileState.url {
                if let mediaInfo = mediaInfoCache[url] {
                    selectedSubtitles = Set(mediaInfo.subtitleStreams.map { $0.streamIndex })
                }
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
            onUpdateOutputService: {},
            mediaInfoCache: [:]
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
            onUpdateOutputService: {},
            mediaInfoCache: [:]
        )
    }
    .frame(width: 400)
}
