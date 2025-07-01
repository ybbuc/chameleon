//
//  AspectRatioVideoPlayer.swift
//  Chameleon
//
//  Created for maintaining video aspect ratio in preview
//

import SwiftUI
import AVKit

struct AspectRatioVideoPlayer: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var aspectRatio: CGFloat = 16/9 // Default aspect ratio
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
                    .aspectRatio(aspectRatio, contentMode: .fit)
                    .background(Color.black)
                    .overlay(
                        Rectangle()
                            .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func loadVideo() {
        let asset = AVAsset(url: url)
        
        Task {
            do {
                // Load the video tracks to get dimensions
                let tracks = try await asset.loadTracks(withMediaType: .video)
                if let track = tracks.first {
                    let size = try await track.load(.naturalSize)
                    let transform = try await track.load(.preferredTransform)
                    
                    // Calculate the actual size considering the transform
                    let transformedSize = size.applying(transform)
                    let width = abs(transformedSize.width)
                    let height = abs(transformedSize.height)
                    
                    await MainActor.run {
                        if height > 0 {
                            self.aspectRatio = width / height
                        }
                        self.player = AVPlayer(url: url)
                    }
                }
            } catch {
                // Fallback to just create the player with default aspect ratio
                await MainActor.run {
                    self.player = AVPlayer(url: url)
                }
            }
        }
    }
}