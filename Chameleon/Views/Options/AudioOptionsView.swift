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
    let inputFormat: FFmpegFormat?
    var inputSampleRate: Int?
    var inputChannels: Int?
    var inputBitDepth: Int?
    var inputBitRate: Int?

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

    private var isInputLossless: Bool {
        guard let format = inputFormat,
              let config = FormatRegistry.shared.config(for: format) else {
            return false
        }
        return config.isLossless
    }

    private var isInputVideo: Bool {
        guard let format = inputFormat else {
            return false
        }
        return format.isVideo
    }

    var body: some View {
        Form {
            // Bit Rate or VBR Quality dropdown (only for lossy formats)
            if let format = outputFormat,
               let config = FormatRegistry.shared.config(for: format),
               config.supportsBitRate {
                if config.supportsVariableBitRate && audioOptions.useVariableBitRate {
                    // VBR Quality dropdown (replaces bit rate when VBR is enabled)
                    HStack {
                        Picker("Bit rate:", selection: $audioOptions.vbrQuality) {
                            ForEach(MP3VBRQuality.allCases, id: \.self) { quality in
                                Text(quality.displayName).tag(quality)
                            }
                        }
                        .pickerStyle(.menu)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .fixedSize()
                        Text("kbps average")
                            .frame(width: 85, alignment: .leading)
                    }

                } else {
                    // Regular bit rate dropdown
                    HStack {
                        Picker("Bit rate:", selection: $audioOptions.bitRate) {
                            if !isInputLossless && !isInputVideo {
                                Text(AudioBitRate.automatic.displayName).tag(AudioBitRate.automatic)

                                Divider()
                            }

                            ForEach(AudioBitRate.allCases.filter { $0 != .automatic }, id: \.self) { bitRate in
                                Text(bitRate.displayName).tag(bitRate)
                            }
                        }
                        .onChange(of: inputFormat) { _, _ in
                            // If input becomes lossless or video and automatic was selected, switch to a default bit rate
                            if (isInputLossless || isInputVideo) && audioOptions.bitRate == .automatic {
                                audioOptions.bitRate = .kbps128
                            }
                        }
                        .pickerStyle(.menu)
                        .transition(.opacity.combined(with: .move(edge: .top)))

                        Text("kbps")
                            .frame(width: 50, alignment: .leading)
                    }
                }
            }

            // Variable Bit Rate toggle (only for formats that support it)
            if let format = outputFormat,
               let config = FormatRegistry.shared.config(for: format),
               config.supportsVariableBitRate {
                Toggle("Use Variable Bit Rate (VBR)", isOn: $audioOptions.useVariableBitRate)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Channels dropdown (for all audio formats)
            Picker("Channels:", selection: $audioOptions.channels) {
                Text(AudioChannels.automatic.displayName).tag(AudioChannels.automatic)

                Divider()

                ForEach(AudioChannels.allCases.filter { $0 != .automatic }, id: \.self) { channels in
                    Text(channels.displayName).tag(channels)
                }
            }
            .pickerStyle(.menu)
            .transition(.opacity.combined(with: .move(edge: .top)))
            .padding(.trailing, 58)

            // Sample Rate dropdown (for all audio formats)
            HStack {
                Picker("Sample rate:", selection: $audioOptions.sampleRate) {
                    if availableSampleRates.contains(.automatic) {
                        Text(AudioSampleRate.automatic.displayName).tag(AudioSampleRate.automatic)

                        Divider()
                    }

                    ForEach(availableSampleRates.filter { $0 != .automatic }, id: \.self) { sampleRate in
                        Text(sampleRate.displayName).tag(sampleRate)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: outputFormat) { _, _ in
                    // Adjust sample rate if current selection is not available for new format
                    if !availableSampleRates.contains(audioOptions.sampleRate) {
                        audioOptions.sampleRate = availableSampleRates.first ?? .hz44100
                    }
                    // Adjust sample size if current selection is not available for new format
                    if !availableSampleSizes.contains(audioOptions.sampleSize) {
                        audioOptions.sampleSize = availableSampleSizes.first ?? .bits16
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))

                Text("Hz")
                    .frame(width: 50, alignment: .leading)
            }

            // Sample Size dropdown (only for lossless formats)
            if let format = outputFormat,
               let config = FormatRegistry.shared.config(for: format),
               config.supportsSampleSize {
                HStack {
                    Picker("Sample Size:", selection: $audioOptions.sampleSize) {
                        ForEach(availableSampleSizes, id: \.self) { sampleSize in
                            Text(sampleSize.displayName).tag(sampleSize)
                        }
                    }
                    .pickerStyle(.menu)
                    .transition(.opacity.combined(with: .move(edge: .top)))

                    Text("bits")
                        .frame(width: 50, alignment: .leading)
                }
            }

            // Resulting file preview
            if let format = outputFormat {
                VStack(alignment: .leading, spacing: 4) {
                    Divider()
                        .padding(.vertical, 4)

                    Text("Resulting File:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(resultingFileDescription(for: format))
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                .padding(.top, 8)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onAppear {
            // If input is lossless or video and automatic is selected, switch to default bit rate
            if (isInputLossless || isInputVideo) && audioOptions.bitRate == .automatic {
                audioOptions.bitRate = .kbps128
            }
        }
        .onChange(of: isInputLossless) { _, newValue in
            // When input lossless status changes, update bit rate if needed
            if newValue && audioOptions.bitRate == .automatic {
                audioOptions.bitRate = .kbps128
            }
        }
        .onChange(of: isInputVideo) { _, newValue in
            // When input video status changes, update bit rate if needed
            if newValue && audioOptions.bitRate == .automatic {
                audioOptions.bitRate = .kbps128
            }
        }
    }

    private func resultingFileDescription(for format: FFmpegFormat) -> String {
        var components: [String] = []

        // Format name
        components.append(format.displayName)

        // Get format config
        guard let config = FormatRegistry.shared.config(for: format) else {
            return components.joined(separator: ", ")
        }

        // Bit rate (for lossy formats)
        if config.supportsBitRate && !audioOptions.useVariableBitRate {
            if audioOptions.bitRate == .automatic {
                if let inputRate = inputBitRate {
                    components.append("\(inputRate) kbps")
                } else {
                    components.append("Source bit rate")
                }
            } else if let bitRateValue = audioOptions.bitRate.value {
                components.append("\(bitRateValue) kbps")
            }
        } else if config.supportsVariableBitRate && audioOptions.useVariableBitRate {
            // Show the VBR quality
            components.append("VBR \(audioOptions.vbrQuality.displayName) kbps")
        }

        // Sample rate
        if audioOptions.sampleRate == .automatic {
            if let inputRate = inputSampleRate {
                components.append("\(inputRate) Hz")
            } else {
                components.append("Source sample rate")
            }
        } else if let sampleRateValue = audioOptions.sampleRate.value {
            components.append("\(sampleRateValue) Hz")
        }

        // Sample size (for lossless formats)
        if config.supportsSampleSize {
            components.append("\(audioOptions.sampleSize.rawValue) bits")
        }

        // Channels
        if audioOptions.channels == .automatic {
            if let inputCh = inputChannels {
                components.append(inputCh == 1 ? "Mono" : inputCh == 2 ? "Stereo" : "\(inputCh) channels")
            } else {
                components.append("Source channels")
            }
        } else {
            components.append(audioOptions.channels.displayName)
        }

        return components.joined(separator: ", ")
    }
}
