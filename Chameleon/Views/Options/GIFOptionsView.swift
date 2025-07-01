//
//  GIFOptionsView.swift
//  Chameleon
//
//  Created by Jakob Wells on 30.06.25.
//

import SwiftUI

struct GIFOptionsView: View {
    @Binding var gifOptions: AnimatedGIFOptions
    @State private var widthText: String = ""
    
    private func sanitizeWidth(_ input: String) -> String {
        // Remove any non-numeric characters
        let cleaned = input.filter { $0.isNumber }
        
        // Limit to reasonable range (50 to 2000 pixels)
        if let value = Int(cleaned) {
            if value < 50 {
                return "50"
            } else if value > 2000 {
                return "2000"
            }
        }
        
        return cleaned
    }
    
    var body: some View {
        Form {
            HStack {
                // FPS setting
                Picker("Frame rate:", selection: $gifOptions.fps) {
                    Text("5").tag(5)
                    Text("10").tag(10)
                    Text("15").tag(15)
                    Text("20").tag(20)
                    Text("25").tag(25)
                    Text("30").tag(30)
                }
                .pickerStyle(.menu)
                
                Text("fps")
                    .frame(width: 50, alignment: .leading)
            }
            // Width setting as text field
            HStack {
                TextField("Width:", text: $widthText)
                    .textFieldStyle(.squareBorder)
                    .frame(width: 100)
                    .onSubmit {
                        // Validate and update the width
                        let sanitized = sanitizeWidth(widthText)
                        widthText = sanitized.isEmpty ? "480" : sanitized
                        gifOptions.width = Int(widthText) ?? 480
                    }
                    .onChange(of: widthText) { _, newValue in
                        // Allow only numbers while typing
                        let filtered = newValue.filter { $0.isNumber }
                        if filtered != newValue {
                            widthText = filtered
                        }
                    }
                Text("pixels")
                    .foregroundColor(.secondary)
            }
            
            // Loop setting - simplified
            Picker("Loop:", selection: $gifOptions.loop) {
                Text("Infinite").tag(0)
                Text("Once").tag(-1)
                Text("Twice").tag(1)
            }
            .pickerStyle(.menu)
            .fixedSize()
            
            // Palette optimization toggle
            Toggle("Optimize colors", isOn: $gifOptions.usePalette)
                .help("Generate optimized color palette for better quality")
        }
        .onAppear {
            // Initialize width text field
            widthText = String(gifOptions.width)
        }
        .onChange(of: gifOptions.width) { _, newValue in
            // Sync changes from outside
            widthText = String(newValue)
        }
    }
}
