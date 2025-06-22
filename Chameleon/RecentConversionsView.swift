//
//  RecentConversionsView.swift
//  Chameleon
//
//  Created by Jakob Wells on 22.06.25.
//

import SwiftUI

struct RecentConversionsView: View {
    @ObservedObject var historyManager: ConversionHistoryManager
    @State private var showingClearAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recent Conversions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if !historyManager.recentConversions.isEmpty {
                    Button("Clear All") {
                        showingClearAlert = true
                    }
                    .foregroundColor(.red)
                    .font(.caption)
                }
            }
            .padding()
            
            Divider()
            
            // Content
            if historyManager.recentConversions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 48))
                        .foregroundStyle(.quaternary)
                    
                    Text("No Recent Conversions")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Saved conversions will appear here.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(historyManager.recentConversions) { record in
                            RecentConversionRow(record: record, historyManager: historyManager)
                            
                            if record.id != historyManager.recentConversions.last?.id {
                                Divider()
                                    .padding(.leading, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .alert("Clear All Conversions", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                historyManager.clearHistory()
            }
        } message: {
            Text("This will remove all conversion history. This action cannot be undone.")
        }
    }
    
    private func deleteConversions(at offsets: IndexSet) {
        for index in offsets {
            let record = historyManager.recentConversions[index]
            historyManager.removeConversion(record)
        }
    }
}

struct RecentConversionRow: View {
    let record: ConversionRecord
    let historyManager: ConversionHistoryManager
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(record.outputFileName)
                    .font(.system(.body, design: .default))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)
                
                HStack(spacing: 12) {
                    Text("\(record.inputFormat) → \(record.outputFormat)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            Text(record.formattedFileSize)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if isHovering || !record.isFileAccessible {
                HStack(spacing: 6) {
                    if record.isFileAccessible {
                        Button {
                            QuickLookManager.shared.previewFile(at: record.outputFileURL)
                        } label: {
                            Image(systemName: "eye")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .help("Quick Look")
                        
                        Button {
                            historyManager.openFile(record)
                        } label: {
                            Image(systemName: "arrowshape.turn.up.right")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .help("Open file")
                        
                        Button {
                            historyManager.revealInFinder(record)
                        } label: {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.plain)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .help("Show in Finder")
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                            .help("File no longer accessible")
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isHovering ? Color.secondary.opacity(0.05) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .contextMenu {
            if record.isFileAccessible {
                Button("Quick Look") {
                    QuickLookManager.shared.previewFile(at: record.outputFileURL)
                }
                
                Button("Open") {
                    historyManager.openFile(record)
                }
                
                Button("Show in Finder") {
                    historyManager.revealInFinder(record)
                }
                
                Divider()
            }
            
            Button("Remove from History", role: .destructive) {
                historyManager.removeConversion(record)
            }
        }
    }
}

#Preview {
    RecentConversionsView(historyManager: ConversionHistoryManager())
}
