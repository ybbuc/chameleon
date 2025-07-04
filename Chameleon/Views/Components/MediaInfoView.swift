//
//  MediaInfoView.swift
//  Chameleon
//
//  Created by Jakob Wells on 28.06.25.
//

import SwiftUI

struct MediaInfoView: View {
    let url: URL
    let cachedMediaInfo: DetailedMediaInfo?
    @State private var mediaInfo: DetailedMediaInfo?
    @State private var isLoading = true
    @State private var error: String?
    
    init(url: URL, cachedMediaInfo: DetailedMediaInfo? = nil) {
        self.url = url
        self.cachedMediaInfo = cachedMediaInfo
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            Text("Media Information")
                .font(.headline)
                .padding(.bottom, 4)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Analyzing file...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let error = error {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Error analyzing file")
                        .font(.subheadline)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let info = mediaInfo {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // General Information
                        InfoSection(title: "General") {
                            InfoRow(label: "Format", value: info.format)
                            InfoRow(label: "File Size", value: formatFileSize(info.fileSize))
                            if let duration = info.duration {
                                InfoRow(label: "Duration", value: formatDuration(duration))
                            }
                            if let overallBitRate = info.overallBitRate {
                                InfoRow(label: "Overall Bit Rate", value: "\(overallBitRate) kbps")
                            }
                        }
                        
                        // Video Streams
                        ForEach(info.videoStreams.indices, id: \.self) { index in
                            let stream = info.videoStreams[index]
                            InfoSection(title: info.videoStreams.count > 1 ? "Video Stream \(index + 1)" : "Video") {
                                if let codec = stream.codec {
                                    InfoRow(label: "Codec", value: codec)
                                }
                                if let resolution = stream.resolution {
                                    InfoRow(label: "Resolution", value: resolution)
                                }
                                if let fps = stream.frameRate {
                                    InfoRow(label: "Frame Rate", value: "\(fps) fps")
                                }
                                if let bitRate = stream.bitRate {
                                    InfoRow(label: "Bit Rate", value: "\(bitRate) kbps")
                                }
                                if let colorSpace = stream.colorSpace {
                                    InfoRow(label: "Color Space", value: colorSpace)
                                }
                                if let pixelFormat = stream.pixelFormat {
                                    InfoRow(label: "Pixel Format", value: pixelFormat)
                                }
                                if let aspectRatio = stream.aspectRatio {
                                    InfoRow(label: "Aspect Ratio", value: aspectRatio)
                                }
                            }
                        }
                        
                        // Audio Streams
                        ForEach(info.audioStreams.indices, id: \.self) { index in
                            let stream = info.audioStreams[index]
                            InfoSection(title: info.audioStreams.count > 1 ? "Audio Stream \(index + 1)" : "Audio") {
                                if let codec = stream.codec {
                                    InfoRow(label: "Codec", value: codec)
                                }
                                if let language = stream.language {
                                    InfoRow(label: "Language", value: language)
                                }
                                if let title = stream.title {
                                    InfoRow(label: "Title", value: title)
                                }
                                if let channels = stream.channels {
                                    InfoRow(label: "Channels", value: channelDescription(channels))
                                }
                                if let sampleRate = stream.sampleRate {
                                    InfoRow(label: "Sample Rate", value: "\(sampleRate) Hz")
                                }
                                if let bitDepth = stream.bitDepth {
                                    InfoRow(label: "Bit Depth", value: "\(bitDepth) bits")
                                }
                                if let bitRate = stream.bitRate {
                                    InfoRow(label: "Bit Rate", value: "\(bitRate) kbps")
                                }
                                if let compressionMode = stream.compressionMode {
                                    InfoRow(label: "Compression", value: compressionMode)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 400, idealWidth: 450, maxWidth: 500, minHeight: 300, idealHeight: 400, maxHeight: 600)
        .onAppear {
            // Use cached info if available
            if let cached = cachedMediaInfo {
                self.mediaInfo = cached
                self.isLoading = false
            } else {
                Task {
                    await loadMediaInfo()
                }
            }
        }
    }
    
    private func loadMediaInfo() async {
        isLoading = true
        error = nil
        
        do {
            // Try MediaInfoLib first
            if let wrapper = try? MediaInfoWrapper() {
                let info = try await Task.detached {
                    try wrapper.getDetailedFileInfo(url: self.url)
                }.value
                
                await MainActor.run {
                    self.mediaInfo = info
                    self.isLoading = false
                }
            } else {
                throw MediaInfoError.libraryNotFound
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func channelDescription(_ channels: Int) -> String {
        switch channels {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(channels)"
        }
    }
}

struct InfoSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 4) {
                content
            }
            .padding(.leading, 12)
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 100, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .textSelection(.enabled)
            
            Spacer()
        }
    }
}

// Stream info structures
struct VideoStreamInfo {
    let streamIndex: Int
    let codec: String?
    let resolution: String?
    let frameRate: Double?
    let bitRate: Int?
    let colorSpace: String?
    let pixelFormat: String?
    let aspectRatio: String?
}

struct AudioStreamInfo {
    let streamIndex: Int
    let codec: String?
    let channels: Int?
    let sampleRate: Int?
    let bitDepth: Int?
    let bitRate: Int?
    let compressionMode: String?
    let language: String?
    let title: String?
}

// Extended media info structure for detailed view
struct DetailedMediaInfo {
    let format: String
    let fileSize: Int64
    let duration: Double?
    let overallBitRate: Int?
    
    let videoStreams: [VideoStreamInfo]
    let audioStreams: [AudioStreamInfo]
    
    var hasVideo: Bool { !videoStreams.isEmpty }
    var hasAudio: Bool { !audioStreams.isEmpty }
    
    // Legacy properties for backward compatibility
    var videoCodec: String? { videoStreams.first?.codec }
    var videoResolution: String? { videoStreams.first?.resolution }
    var videoFrameRate: Double? { videoStreams.first?.frameRate }
    var videoBitRate: Int? { videoStreams.first?.bitRate }
    var videoColorSpace: String? { videoStreams.first?.colorSpace }
    
    var audioCodec: String? { audioStreams.first?.codec }
    var audioChannels: Int? { audioStreams.first?.channels }
    var audioSampleRate: Int? { audioStreams.first?.sampleRate }
    var audioBitDepth: Int? { audioStreams.first?.bitDepth }
    var audioBitRate: Int? { audioStreams.first?.bitRate }
    var audioCompressionMode: String? { audioStreams.first?.compressionMode }
}