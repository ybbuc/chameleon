//
//  AudioOptionsView.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI

struct AudioOptionsView: View {
    @Binding var audioOptions: AudioOptions
    let outputFormat: FFmpegFormat?
    
    private var availableSampleRates: [AudioSampleRate] {
        guard let format = outputFormat,
              let config = FormatRegistry.shared.config(for: format) else {
            return AudioSampleRate.defaultSampleRates
        }
        return config.availableSampleRates
    }
    
    private var availableSampleSizes: [AudioSampleSize] {
        guard let format = outputFormat,
              let config = FormatRegistry.shared.config(for: format) else {
            return AudioSampleSize.allCases
        }
        return config.availableSampleSizes
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Bit Rate dropdown (only for lossy formats)
            if let format = outputFormat,
               let config = FormatRegistry.shared.config(for: format),
               config.supportsBitRate {
                HStack {
                    Spacer()
                    Picker("Bit Rate", selection: $audioOptions.bitRate) {
                        ForEach(AudioBitRate.allCases, id: \.self) { bitRate in
                            Text(bitRate.displayName).tag(bitRate)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Channels dropdown
            HStack {
                Spacer()
                Picker("Channels", selection: $audioOptions.channels) {
                    ForEach(AudioChannels.allCases, id: \.self) { channels in
                        Text(channels.displayName).tag(channels)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            
            // Sample Rate dropdown
            HStack {
                Spacer()
                Picker("Sample Rate", selection: $audioOptions.sampleRate) {
                    ForEach(availableSampleRates, id: \.self) { sampleRate in
                        Text(sampleRate.displayName).tag(sampleRate)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .onChange(of: outputFormat) { _, newFormat in
                    // Adjust sample rate if current selection is not available for new format
                    if !availableSampleRates.contains(audioOptions.sampleRate) {
                        audioOptions.sampleRate = availableSampleRates.first ?? .hz44100
                    }
                    // Adjust sample size if current selection is not available for new format
                    if !availableSampleSizes.contains(audioOptions.sampleSize) {
                        audioOptions.sampleSize = availableSampleSizes.first ?? .bits16
                    }
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            
            // Sample Size dropdown (only for lossless formats)
            if let format = outputFormat,
               let config = FormatRegistry.shared.config(for: format),
               config.supportsSampleSize {
                HStack {
                    Spacer()
                    Picker("Sample Size", selection: $audioOptions.sampleSize) {
                        ForEach(availableSampleSizes, id: \.self) { sampleSize in
                            Text(sampleSize.displayName).tag(sampleSize)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
            }
            
            // Variable Bit Rate toggle (only for formats that support it)
            if let format = outputFormat,
               let config = FormatRegistry.shared.config(for: format),
               config.supportsVariableBitRate {
                HStack {
                    Spacer()
                    Toggle("Use Variable Bit Rate (VBR)", isOn: $audioOptions.useVariableBitRate)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
