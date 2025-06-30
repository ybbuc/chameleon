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
    
    var body: some View {
        VStack(spacing: 12) {
            Form {
                // Resolution dropdown
                HStack {
                    Spacer()
                    Picker("Resolution:", selection: $videoOptions.resolution) {
                        ForEach(VideoResolution.allCases, id: \.self) { resolution in
                            Text(resolution.displayName).tag(resolution)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                // Quality dropdown
                HStack {
                    Spacer()
                    Picker("Quality:", selection: $videoOptions.quality) {
                        ForEach(FFmpegQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.menu)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
