//
//  ContentView.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import SwiftUI
import SwiftData

enum ViewMode: String, CaseIterable {
    case convert = "Convert"
    case history = "Saved"
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMode: ViewMode = .convert
    @State private var searchText = ""
    @State private var savedHistoryManager: SavedHistoryManager?

    var body: some View {
        Group {
            if let manager = savedHistoryManager {
                ZStack {
                    ConverterView(savedHistoryManager: manager)
                        .opacity(selectedMode == .convert ? 1 : 0)
                        .allowsHitTesting(selectedMode == .convert)

                    if selectedMode == .history {
                        SavedHistoryView(searchText: $searchText, savedHistoryManager: manager)
                            .searchable(text: $searchText, prompt: "Search history")
                    }
                }
            } else {
                ProgressView("Loading...")
            }
        }
        .onAppear {
            if savedHistoryManager == nil {
                savedHistoryManager = SavedHistoryManager(modelContext: modelContext)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("View Mode", selection: $selectedMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
        }
        .navigationTitle("")
        .frame(minWidth: 800, minHeight: 400)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ConversionRecord.self], inMemory: true)
}
