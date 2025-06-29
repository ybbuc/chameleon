//
//  ImageOptionsView.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import SwiftUI

struct ImageOptionsView: View {
    @Binding var imageQuality: Double
    @Binding var useLossyCompression: Bool
    @Binding var removeExifMetadata: Bool
    @Binding var pdfToDpi: Int
    
    let outputFormat: ImageFormat?
    let inputFileURLs: [URL]
    
    private var shouldShowDpiSelector: Bool {
        let hasInputRequiringDpi = inputFileURLs.contains { url in
            guard let format = ImageFormat.detectFormat(from: url) else { return false }
            return format.requiresDpiConfiguration
        }
        return hasInputRequiringDpi
    }
    
    private var shouldShowExifOption: Bool {
        guard let format = outputFormat else { return false }
        return format.supportsExifMetadata
    }
    
    private var pdfToDpiIndex: Int {
        switch pdfToDpi {
        case 72: return 0
        case 150: return 1
        case 300: return 2
        case 600: return 3
        case 1200: return 4
        case 2400: return 5
        default: return 1
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Show DPI selector when converting PDF to image
            if shouldShowDpiSelector {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("PDF Resolution")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(pdfToDpi) DPI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { Double(pdfToDpiIndex) },
                                set: { newValue in
                                    let dpiValues = [72, 150, 300, 600, 1200, 2400]
                                    let index = Int(newValue)
                                    pdfToDpi = dpiValues[min(max(0, index), dpiValues.count - 1)]
                                }
                            ),
                            in: 0...5,
                            step: 1
                        )
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Show EXIF metadata removal toggle for image conversions
            if shouldShowExifOption {
                HStack {
                    Spacer()
                    Toggle("Strip EXIF Metadata", isOn: $removeExifMetadata)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Show quality controls for lossy image conversions
            if let format = outputFormat, format.isLossy {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Spacer()
                        Toggle("Lossy Compression", isOn: $useLossyCompression)
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    
                    HStack {
                        Text("Image Quality")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(useLossyCompression ? "\(Int(imageQuality))" : "Default")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    VStack(spacing: 4) {
                        Slider(value: $imageQuality,
                                in: 1...100,
                                minimumValueLabel: Text("1").font(.caption2),
                                maximumValueLabel: Text("100").font(.caption2),
                                label: {
                                    Text("Quality")
                                }
                            )
                            .labelsHidden()
                            .disabled(!useLossyCompression)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
