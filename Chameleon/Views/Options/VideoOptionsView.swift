//
//  VideoOptionsView.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import SwiftUI

struct VideoOptionsView: View {
    @Binding var videoOptions: VideoOptions
    let outputFormat: FFmpegFormat?
    
    private var crfRange: ClosedRange<Double> {
        guard let format = outputFormat,
              let codec = format.primaryVideoCodec(for: videoOptions.encoder),
              case let .supported(min, max, _) = VideoCodecCRFSupport.forCodec(codec) else {
            return 0...51 // Default to x264 range
        }
        return Double(min)...Double(max)
    }
    
    private var codecSupportsCRF: Bool {
        guard let format = outputFormat,
              let codec = format.primaryVideoCodec(for: videoOptions.encoder) else {
            return true
        }
        if case .supported = VideoCodecCRFSupport.forCodec(codec) {
            return true
        }
        return false
    }
    
    private var formatSupportsEncoderSelection: Bool {
        guard let format = outputFormat,
              let config = FormatRegistry.shared.config(for: format) else {
            return false
        }
        return !config.supportedVideoEncoders().isEmpty
    }
    
    private func sanitizeBitrate(_ input: String) -> String {
        // Remove any non-numeric characters except decimal point
        let cleaned = input.filter { $0.isNumber || $0 == "." }
        
        // Ensure only one decimal point
        let parts = cleaned.split(separator: ".")
        if parts.count > 2 {
            return String(parts[0]) + "." + parts[1...].joined()
        }
        
        // Limit to reasonable range (0.1 to 100 Mbps)
        if let value = Double(cleaned) {
            if value < 0.1 {
                return "0.1"
            } else if value > 100 {
                return "100"
            }
        }
        
        return cleaned.isEmpty ? "5" : cleaned
    }
    
    var body: some View {
        Form {
            // Show GIF-specific options if output format is GIF
            if outputFormat == .gif {
                GIFOptionsView(gifOptions: $videoOptions.gifOptions)
            } else {
                // Resolution dropdown for non-GIF formats
                Picker("Resolution:", selection: $videoOptions.resolution) {
                Text(VideoResolution.automatic.displayName).tag(VideoResolution.automatic)
                Divider()
                ForEach([VideoResolution.res480p, VideoResolution.res576p, VideoResolution.res720p, VideoResolution.res1080p, VideoResolution.res1440p, VideoResolution.res2160p, VideoResolution.res4320p], id: \.self) { resolution in
                    Text(resolution.displayName).tag(resolution)
                }
            }
            .pickerStyle(.menu)
            .padding(.trailing, 58)
            .onChange(of: videoOptions.resolution) { _, newResolution in
                // Auto-adjust bitrate when resolution changes in bitrate mode
                if videoOptions.qualityMode == .bitrate && newResolution != .automatic {
                    videoOptions.customBitrate = VideoBitrate.recommendedValue(for: newResolution)
                }
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            
            // Aspect ratio dropdown
            Picker("Aspect ratio:", selection: $videoOptions.aspectRatio) {
                Text(VideoAspectRatio.automatic.displayName).tag(VideoAspectRatio.automatic)
                Divider()
                ForEach([VideoAspectRatio.fourThree, VideoAspectRatio.sixteenNine, VideoAspectRatio.square], id: \.self) { ratio in
                    Text(ratio.displayName).tag(ratio)
                }
            }
            .pickerStyle(.menu)
            .padding(.trailing, 58)
            .transition(.opacity.combined(with: .move(edge: .top)))
            
            // Encoder selector - only show if format supports multiple encoders
            if formatSupportsEncoderSelection,
               let format = outputFormat,
               let config = FormatRegistry.shared.config(for: format) {
                Picker("Encoder:", selection: $videoOptions.encoder) {
                    ForEach(config.supportedVideoEncoders(), id: \.self) { encoder in
                        Text(encoder.displayName).tag(encoder)
                    }
                }
                .pickerStyle(.segmented)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Preset selector - only show for x264 and x265 encoders
            if videoOptions.encoder == .x264 || videoOptions.encoder == .x265 {
                VStack(alignment: .leading, spacing: 4) {
                    Picker("Preset:", selection: $videoOptions.preset) {
                        ForEach(VideoPreset.allCases, id: \.self) { preset in
                            Text(preset.displayName).tag(preset)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.trailing, 58)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Quality mode selector - only show if codec supports CRF
            if codecSupportsCRF {
                Picker("Quality:", selection: $videoOptions.qualityMode) {
                    ForEach(VideoQualityMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Quality settings based on mode
            if codecSupportsCRF && videoOptions.qualityMode == .constantRateFactor {
                // CRF Quality slider
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("CRF")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(videoOptions.crfValue))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    
                    HStack {
                        Text("Best")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Slider(
                            value: $videoOptions.crfValue,
                            in: crfRange
                        )
                        .labelsHidden()
                        Text("Smallest")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
                // Show bitrate field when in bitrate mode OR when codec doesn't support CRF
                if !codecSupportsCRF || videoOptions.qualityMode == .bitrate {
                    // Bitrate text field
                    HStack {
                        TextField("Bit rate:", text: $videoOptions.customBitrate)
                            .textFieldStyle(.squareBorder)
                            .frame(width: 100)
                            .onSubmit {
                                // Validate and clean up the input
                                videoOptions.customBitrate = sanitizeBitrate(videoOptions.customBitrate)
                            }
                            .onChange(of: videoOptions.customBitrate) { _, newValue in
                                // Allow only numbers and decimal point while typing
                                let filtered = newValue.filter { $0.isNumber || $0 == "." }
                                if filtered != newValue {
                                    videoOptions.customBitrate = filtered
                                }
                            }
                        Text("Mbps")
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    
                    // Two-pass encoding toggle - only show if codec supports CRF
                    if codecSupportsCRF {
                        Toggle("Two-pass encoding", isOn: $videoOptions.useTwoPassEncoding)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
        .onAppear {
            // Set initial bitrate based on current resolution if it's still the default
            if videoOptions.customBitrate == "5" {
                videoOptions.customBitrate = VideoBitrate.recommendedValue(for: videoOptions.resolution)
            }
            
            // Force bitrate mode if codec doesn't support CRF
            if !codecSupportsCRF {
                videoOptions.qualityMode = .bitrate
            } else if let format = outputFormat,
                      let codec = format.primaryVideoCodec(for: videoOptions.encoder),
                      case let .supported(_, _, defaultCRF) = VideoCodecCRFSupport.forCodec(codec),
                      videoOptions.crfValue == 23 { // Only update if it's still the x264 default
                videoOptions.crfValue = Double(defaultCRF)
            }
        }
        .onChange(of: outputFormat) { _, newFormat in
            // Update CRF default when format changes
            if let format = newFormat,
               let codec = format.primaryVideoCodec(for: videoOptions.encoder),
               case let .supported(_, _, defaultCRF) = VideoCodecCRFSupport.forCodec(codec) {
                videoOptions.crfValue = Double(defaultCRF)
            }
            
            // Force bitrate mode if new format doesn't support CRF
            if !codecSupportsCRF {
                videoOptions.qualityMode = .bitrate
            }
        }
        .onChange(of: videoOptions.encoder) { _, newEncoder in
            // Update CRF default when encoder changes
            if let format = outputFormat,
               let codec = format.primaryVideoCodec(for: newEncoder),
               case let .supported(_, _, defaultCRF) = VideoCodecCRFSupport.forCodec(codec) {
                videoOptions.crfValue = Double(defaultCRF)
            }
            
            // Force bitrate mode if new encoder doesn't support CRF
            if !codecSupportsCRF {
                videoOptions.qualityMode = .bitrate
            }
        }
        .onChange(of: codecSupportsCRF) { _, supports in
            // Force bitrate mode when codec support changes
            if !supports {
                videoOptions.qualityMode = .bitrate
            }
        }
    }
}
