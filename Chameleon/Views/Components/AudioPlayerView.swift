//
//  AudioPlayerView.swift
//  Chameleon
//
//  Created for audio file playback controls
//

import SwiftUI
import AVKit

struct AudioPlayerView: View {
    let url: URL
    @StateObject private var audioPlayer = AudioPlayerViewModel()
    @State private var isHoveringProgressBar = false
    @State private var hoverProgress: CGFloat = 0
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
            
            VStack(spacing: 0) {
                // Audio visualization area
                VStack(spacing: 12) {
                    Image(systemName: "waveform")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.4))
                    
                    if !audioPlayer.title.isEmpty || audioPlayer.artist != nil {
                        VStack(spacing: 4) {
                            if !audioPlayer.title.isEmpty {
                                Text(audioPlayer.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.horizontal)
                                    .opacity(audioPlayer.isLoadingMetadata ? 0 : 1.0)
                                    .animation(.easeInOut(duration: 0.3), value: audioPlayer.isLoadingMetadata)
                            }
                            
                            if let artist = audioPlayer.artist {
                                Text(artist)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .padding(.horizontal)
                                    .opacity(audioPlayer.isLoadingMetadata ? 0 : 1.0)
                                    .animation(.easeInOut(duration: 0.3), value: audioPlayer.isLoadingMetadata)
                            }
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .frame(maxHeight: .infinity)
                .padding()
                
                // Controls section
                VStack(spacing: 12) {
                // Progress bar with time
                VStack(spacing: 4) {
                    ZStack {
                        // Reserve space for tooltip
                        Color.clear
                            .frame(height: 25)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 6)
                                    .frame(maxWidth: .infinity)
                                    .position(x: geometry.size.width / 2, y: 12.5)
                                
                                // Progress fill
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.primary.opacity(0.6))
                                    .frame(width: geometry.size.width * CGFloat(audioPlayer.progress), height: 6)
                                    .position(x: geometry.size.width * CGFloat(audioPlayer.progress) / 2, y: 12.5)
                                
                                // Hover indicator (overlay, doesn't affect layout)
                                if isHoveringProgressBar {
                                    let xOffset = geometry.size.width * hoverProgress
                                    let tooltipWidth: CGFloat = 50
                                    let clampedXOffset = max(tooltipWidth/2, min(xOffset, geometry.size.width - tooltipWidth/2))
                                    
                                    // Hover position indicator
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(Color.secondary)
                                        .frame(width: 4, height: 12)
                                        .position(x: xOffset, y: 12.5)
                                    
                                    // Time tooltip
                                    Text(formatTime(audioPlayer.duration * Double(hoverProgress)))
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color.black.opacity(0.8))
                                        )
                                        .fixedSize()
                                        .position(x: clampedXOffset, y: -10)
                                        .opacity(isHoveringProgressBar ? 1 : 0)
                                        .animation(.easeOut(duration: 0.15), value: isHoveringProgressBar)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                let progress = location.x / geometry.size.width
                                audioPlayer.seek(to: progress)
                            }
                            .onHover { hovering in
                                isHoveringProgressBar = hovering
                            }
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    hoverProgress = location.x / geometry.size.width
                                case .ended:
                                    break
                                }
                            }
                        }
                        .frame(height: 25)
                    }
                    
                    HStack {
                        Text(formatTime(audioPlayer.currentTime))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                        Spacer()
                        Text(formatTime(audioPlayer.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal)
                
                // Playback controls
                HStack(spacing: 40) {
                    // Skip backward 10s
                    Button(action: {
                        audioPlayer.skip(by: -10)
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .help("Skip backward 10 seconds")
                    
                    // Play/Pause
                    Button(action: {
                        audioPlayer.togglePlayPause()
                    }) {
                        Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                            .frame(width: 36, height: 36)
                            .font(.system(size: 36))
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                    .help(audioPlayer.isPlaying ? "Pause" : "Play")
                    
                    // Skip forward 10s
                    Button(action: {
                        audioPlayer.skip(by: 15)
                    }) {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .help("Skip forward 10 seconds")
                }
            }
            .padding()
            .padding(.bottom, 8) // Extra bottom padding for controls
            }
        }
        .onAppear {
            audioPlayer.loadAudio(from: url)
        }
        .onDisappear {
            audioPlayer.stop()
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// ViewModel for audio playback
class AudioPlayerViewModel: ObservableObject {
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var fileURL: URL?
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var title: String = ""
    @Published var artist: String? = nil
    @Published var isLoadingMetadata = true
    
    func loadAudio(from url: URL) {
        fileURL = url
        player = AVPlayer(url: url)
        
        // Start with no title
        title = ""
        artist = nil
        isLoadingMetadata = true
        
        // Get duration and metadata
        Task { [weak self] in
            guard let self = self,
                  let item = self.player?.currentItem else { return }
            
            do {
                // Load duration
                let duration = try await item.asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(duration)
                
                // Load common metadata
                let commonMetadata = try await item.asset.load(.commonMetadata)
                
                await MainActor.run {
                    self.duration = durationInSeconds.isFinite ? durationInSeconds : 0
                    
                    // Try common metadata first (works for most formats)
                    if !commonMetadata.isEmpty {
                        self.extractMetadata(from: commonMetadata)
                    } else {
                        // Fallback to general metadata
                        Task {
                            do {
                                let metadata = try await item.asset.load(.metadata)
                                await MainActor.run {
                                    self.extractMetadata(from: metadata)
                                }
                            } catch {
                                print("Failed to load general metadata: \(error)")
                                await MainActor.run {
                                    // Keep filename on error
                                    self.isLoadingMetadata = false
                                }
                            }
                        }
                    }
                }
            } catch {
                print("Failed to load asset properties: \(error)")
                await MainActor.run {
                    // Keep filename on error
                    self.isLoadingMetadata = false
                }
            }
        }
        
        // Observe playback time
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            let currentSeconds = CMTimeGetSeconds(time)
            self.currentTime = currentSeconds.isFinite ? currentSeconds : 0
            
            if self.duration > 0 {
                self.progress = self.currentTime / self.duration
            }
        }
        
        // Observe when playback ends
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player?.currentItem
        )
    }
    
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    func skip(by seconds: Double) {
        guard let player = player else { return }
        
        let currentTime = CMTimeGetSeconds(player.currentTime())
        let newTime = currentTime + seconds
        let clampedTime = max(0, min(newTime, duration))
        
        player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600))
    }
    
    func seek(to progress: Double) {
        guard let player = player else { return }
        
        let newTime = duration * progress
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }
    
    func stop() {
        player?.pause()
        isPlaying = false
        
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        player = nil
    }
    
    @objc private func playerDidFinishPlaying() {
        isPlaying = false
        player?.seek(to: .zero)
    }
    
    private func extractMetadata(from items: [AVMetadataItem]) {
        Task { @MainActor in
            var extractedTitle: String?
            var extractedArtist: String?
            
            for item in items {
                guard let key = item.commonKey?.rawValue else { continue }
                
                // Extract string value from metadata item using modern API
                let value: String? = await {
                    // Try to load as string first
                    if let stringValue = try? await item.load(.stringValue) {
                        return stringValue
                    }
                    // Fall back to data value
                    if let dataValue = try? await item.load(.dataValue),
                       let string = String(data: dataValue, encoding: .utf8) {
                        return string
                    }
                    return nil
                }()
                
                switch key {
                case AVMetadataKey.commonKeyTitle.rawValue:
                    extractedTitle = value
                case AVMetadataKey.commonKeyArtist.rawValue:
                    extractedArtist = value
                case AVMetadataKey.commonKeyAlbumName.rawValue:
                    // Could also extract album if needed
                    break
                default:
                    break
                }
            }
            
            // Only show title if metadata exists
            if let extractedTitle = extractedTitle, !extractedTitle.isEmpty {
                title = extractedTitle
            }
            // Otherwise title remains empty
            
            // Update artist if found
            artist = extractedArtist
            
            // Mark metadata loading as complete
            isLoadingMetadata = false
        }
    }
    
    deinit {
        stop()
    }
}

#Preview {
    AudioPlayerView(url: URL(fileURLWithPath: "/System/Library/Sounds/Glass.aiff"))
        .frame(width: 400, height: 400)
}
