//
//  SavedHistoryView.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI
import SwiftData

struct SavedHistoryView: View {
    @Binding var searchText: String
    @ObservedObject var savedHistoryManager: SavedHistoryManager
    @State private var showingClearAlert = false
    @State private var showingClearMissingAlert = false
    @AppStorage("autoClearMissingFiles") private var autoClearMissingFiles: Bool = false

    private var filteredConversions: [ConversionRecord] {
        if searchText.isEmpty {
            return savedHistoryManager.savedHistory
        } else {
            return savedHistoryManager.savedHistory.filter { record in
                record.inputFileName.localizedCaseInsensitiveContains(searchText) ||
                record.outputFileName.localizedCaseInsensitiveContains(searchText) ||
                record.inputFormat.localizedCaseInsensitiveContains(searchText) ||
                record.outputFormat.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header - always show
            HStack {
                Spacer()

                Button("Clear Missing") {
                    showingClearMissingAlert = true
                }
                .foregroundColor(savedHistoryManager.hasMissingFiles ? .orange : .secondary)
                .buttonStyle(.bordered)
                .disabled(!savedHistoryManager.hasMissingFiles || savedHistoryManager.savedHistory.isEmpty)

                Button("Clear History") {
                    showingClearAlert = true
                }
                .foregroundColor(.red)
                .buttonStyle(.bordered)
                .disabled(savedHistoryManager.savedHistory.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 16)

            Divider()

            // Content
            if savedHistoryManager.savedHistory.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        .font(.system(size: 64))
                        .foregroundStyle(.quaternary)

                    Text("No Saved History")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Saved conversions appear here.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredConversions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundStyle(.quaternary)

                    Text("No Results Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Try adjusting your search terms.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredConversions) { record in
                            SavedHistoryRow(
                                record: record,
                                savedHistoryManager: savedHistoryManager,
                                searchText: searchText
                            )

                            if record.id != filteredConversions.last?.id {
                                Divider()
                                    .padding(.horizontal, 24)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .alert("Clear History", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear History", role: .destructive) {
                savedHistoryManager.clearSavedHistory()
            }
        } message: {
            Text("This will remove all saved history. This action cannot be undone.")
        }
        .alert("Clear Missing Files", isPresented: $showingClearMissingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear Missing", role: .destructive) {
                savedHistoryManager.clearMissingFiles()
            }
        } message: {
            Text("This will remove all saved history entries for files that no longer exist. " +
                 "This action cannot be undone.")
        }
        .onAppear {
            savedHistoryManager.checkForMissingFiles()
            if autoClearMissingFiles && savedHistoryManager.hasMissingFiles {
                savedHistoryManager.clearMissingFiles()
            }
        }
    }
}

struct SavedHistoryRow: View {
    let record: ConversionRecord
    let savedHistoryManager: SavedHistoryManager
    let searchText: String
    @State private var isHovering = false
    @State private var showingDeleteAlert = false
    @State private var isFileAccessible: Bool = true
    @State private var cachedThumbnail: NSImage?

    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail or file icon
            Group {
                if let thumbnailImage = cachedThumbnail {
                    Image(nsImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    Image(systemName: fileIcon)
                        .font(.system(size: 20))
                        .foregroundColor(.secondary)
                        .frame(width: 40, height: 40)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                // File name with search highlighting and file size
                HStack {
                    Text(highlightedText(record.outputFileName, searchText: searchText))
                        .font(.system(.body, design: .default))
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .foregroundColor(.primary)

                    Spacer()

                    Text(record.formattedFileSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 12) {
                    // Format conversion
                    HStack(spacing: 4) {
                        Text(record.inputFormat.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)

                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Text(record.outputFormat.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Relative time
                    Text(record.relativeTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !isFileAccessible {
                Spacer()

                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .help("File no longer accessible")
            }

            if isHovering {
                HStack(spacing: 8) {
                    if isFileAccessible {
                        Button {
                            QuickLookManager.shared.previewFile(at: record.outputFileURL)
                        } label: {
                            Image(systemName: "eye")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .help("Quick Look")

                        Button {
                            savedHistoryManager.openFile(record)
                        } label: {
                            Image(systemName: "arrowshape.turn.up.right")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .help("Open file")

                        Button {
                            savedHistoryManager.revealInFinder(record)
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .help("Show in Finder")
                    }

                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .help("Remove from saved history")
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(isHovering ? Color.secondary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
            if hovering {
                // Check file accessibility when hovering
                isFileAccessible = record.isFileAccessible
                savedHistoryManager.checkForMissingFiles()
            }
        }
        .alert("Remove from Saved History", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                savedHistoryManager.removeConversion(record)
            }
        } message: {
            Text("Are you sure you want to remove \"\(record.outputFileName)\" from your saved history?")
        }
        .contextMenu {
            if isFileAccessible {
                Button("Quick Look") {
                    QuickLookManager.shared.previewFile(at: record.outputFileURL)
                }

                Button("Open") {
                    savedHistoryManager.openFile(record)
                }

                Button("Show in Finder") {
                    savedHistoryManager.revealInFinder(record)
                }

                Divider()
            }

            Button("Remove from Saved History", role: .destructive) {
                showingDeleteAlert = true
            }
        }
        .onAppear {
            isFileAccessible = record.isFileAccessible
            cachedThumbnail = record.thumbnailImage
        }
    }

    private var fileIcon: String {
        let ext = record.outputFormat.lowercased()
        switch ext {
        case "pdf", "rtf": return "doc.richtext"
        case "png", "jpg", "jpeg", "bmp", "tiff", "webp", "tif": return "photo"
        case "gif": return "photo.on.rectangle.angled"
        case "html", "htm": return "globe"
        case "md", "txt": return "doc.text"
        case "mp4", "mov", "avi", "mkv", "webm", "flv", "wmv", "m4v": return "video"
        case "aac", "mp3", "wav", "flac", "alac", "ogg", "wma", "aiff": return "waveform"
        default: return "doc"
        }
    }

    private func highlightedText(_ text: String, searchText: String) -> AttributedString {
        guard !searchText.isEmpty else {
            return AttributedString(text)
        }

        var attributedString = AttributedString(text)

        if let range = text.range(of: searchText, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: text)
            if let attributedRange = Range<AttributedString.Index>(nsRange, in: attributedString) {
                attributedString[attributedRange].backgroundColor = .yellow.opacity(0.3)
                attributedString[attributedRange].foregroundColor = .primary
            }
        }

        return attributedString
    }
}

#Preview {
    @Previewable @State var searchText = ""
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = (try? ModelContainer(for: ConversionRecord.self, configurations: config)) ??
                    (try! ModelContainer(for: ConversionRecord.self,
                                       configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    let context = container.mainContext
    let manager = SavedHistoryManager(modelContext: context)

    SavedHistoryView(
        searchText: $searchText,
        savedHistoryManager: manager
    )
    .modelContainer(container)
}
