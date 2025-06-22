//
//  ContentView.swift
//  Chameleon
//
//  Created by Jakob Wells on 21.06.25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        ConverterView()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
