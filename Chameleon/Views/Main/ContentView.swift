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

class FileSelectionController: ObservableObject {
    var selectFileAction: (() -> Void)?
    
    func selectFile() {
        selectFileAction?()
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedMode: ViewMode = .convert
    @State private var searchText = ""
    @State private var savedHistoryManager: SavedHistoryManager?
    @StateObject private var fileSelectionController = FileSelectionController()

    var body: some View {
        Group {
            if let manager = savedHistoryManager {
                ZStack {
                    ConverterView(savedHistoryManager: manager, fileSelectionController: fileSelectionController)
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
            ToolbarItem(placement: .navigation) {
                if selectedMode == .convert {
                    Button {
                        fileSelectionController.selectFile()
                    } label: {
                        Label("Add Files", systemImage: "plus")
                    }
                }
            }
            
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
