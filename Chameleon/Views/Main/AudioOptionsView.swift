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
        switch outputFormat {
        case .mp3:
            return AudioSampleRate.mp3SampleRates
        case .flac, .alac:
            return AudioSampleRate.flacSampleRates
        case .wav:
            return AudioSampleRate.wavSampleRates
        case .aiff:
            return AudioSampleRate.aiffSampleRates
        default:
            return AudioSampleRate.defaultSampleRates
        }
    }
    
    private var availableSampleSizes: [AudioSampleSize] {
        switch outputFormat {
        case .flac:
            return AudioSampleSize.flacSampleSizes
        case .alac:
            return AudioSampleSize.alacSampleSizes
        case .wav:
            return AudioSampleSize.wavSampleSizes
        case .aiff:
            return AudioSampleSize.aiffSampleSizes
        default:
            return AudioSampleSize.allCases
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Bit Rate dropdown (not for lossless formats like FLAC, ALAC, WAV, and AIFF)
            if outputFormat != .flac && outputFormat != .alac && outputFormat != .wav && outputFormat != .aiff {
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
            
            // Sample Size dropdown (only for lossless formats like FLAC, ALAC, WAV, and AIFF)
            if outputFormat == .flac || outputFormat == .alac || outputFormat == .wav || outputFormat == .aiff {
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
            
            // Variable Bit Rate toggle (only for MP3)
            if outputFormat == .mp3 {
                HStack {
                    Spacer()
                    Toggle("Use Variable Bit Rate (VBR)", isOn: $audioOptions.useVariableBitRate)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }
        }
    }
}
