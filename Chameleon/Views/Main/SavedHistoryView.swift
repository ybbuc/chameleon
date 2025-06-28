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
            // Header - only show when there are conversions
            if !savedHistoryManager.savedHistory.isEmpty {
                HStack {
                    Spacer()
                    
                    Button("Clear History") {
                        showingClearAlert = true
                    }
                    .foregroundColor(.red)
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
            }
            
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
    }
}

struct SavedHistoryRow: View {
    let record: ConversionRecord
    let savedHistoryManager: SavedHistoryManager
    let searchText: String
    @State private var isHovering = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Thumbnail or file icon
            Group {
                if let thumbnailImage = record.thumbnailImage {
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
                        .font(.system(size: 24))
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
                    // Format conversion badge
                    HStack(spacing: 4) {
                        Text(record.inputFormat.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(record.outputFormat.uppercased())
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    // Relative time
                    Text(record.relativeTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if !record.isFileAccessible {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .help("File no longer accessible")
            }
            
            if isHovering {
                HStack(spacing: 8) {
                    if record.isFileAccessible {
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
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .help("Remove from saved history")
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background(isHovering ? Color.secondary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
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
            if record.isFileAccessible {
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
    }
    
    private var fileIcon: String {
        let ext = record.outputFormat.lowercased()
        switch ext {
        case "pdf", "rtf": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp", "tif": return "photo"
        case "html", "htm": return "globe"
        case "md", "txt": return "doc.text"
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
    let container = try! ModelContainer(for: ConversionRecord.self, configurations: config)
    let context = container.mainContext
    let manager = SavedHistoryManager(modelContext: context)
    
    SavedHistoryView(
        searchText: $searchText,
        savedHistoryManager: manager
    )
    .modelContainer(container)
}
