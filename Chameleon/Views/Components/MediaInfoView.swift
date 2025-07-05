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
    
    @State private var selectedTab = "general"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                TabView(selection: $selectedTab) {
                    // General Tab
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            InfoRow(label: "Filename", value: url.lastPathComponent)
                            InfoRow(label: "Format", value: info.format)
                            InfoRow(label: "File Size", value: formatFileSize(info.fileSize))
                            if let createdDate = info.createdDate {
                                InfoRow(label: "Created", value: formatDate(createdDate))
                            }
                            if let modifiedDate = info.modifiedDate {
                                InfoRow(label: "Modified", value: formatDate(modifiedDate))
                            }
                            if let duration = info.duration {
                                InfoRow(label: "Duration", value: formatDuration(duration))
                            }
                            if let overallBitRate = info.overallBitRate {
                                InfoRow(label: "Overall Bit Rate", value: "\(overallBitRate) kbps")
                            }
                            if let overallBitRateMode = info.overallBitRateMode {
                                InfoRow(label: "Overall Bit Rate Mode", value: overallBitRateMode)
                            }
                            if let encodingApplication = info.encodingApplication {
                                InfoRow(label: "Encoding Application", value: encodingApplication)
                            }
                            if let writingLibrary = info.writingLibrary {
                                InfoRow(label: "Writing Library", value: writingLibrary)
                            }
                        }
                        .padding()
                    }
                    .tabItem {
                        Text("General")
                    }
                    .tag("general")
                    
                    // Video Tab
                    if info.hasVideo {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(info.videoStreams.indices, id: \.self) { index in
                                    let stream = info.videoStreams[index]
                                    if info.videoStreams.count > 1 {
                                        InfoSection(title: "Video Stream \(index + 1)") {
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
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
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
                                }
                            }
                            .padding()
                        }
                        .tabItem {
                            Text("Video")
                        }
                        .tag("video")
                    }
                    
                    // Audio Tab
                    if info.hasAudio {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(info.audioStreams.indices, id: \.self) { index in
                                    let stream = info.audioStreams[index]
                                    if info.audioStreams.count > 1 {
                                        InfoSection(title: "Audio Stream \(index + 1)") {
                                            if let codec = stream.codec {
                                                InfoRow(label: "Codec", value: formatAudioCodec(codec))
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
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let codec = stream.codec {
                                                InfoRow(label: "Codec", value: formatAudioCodec(codec))
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
                            .padding()
                        }
                        .tabItem {
                            Text("Audio")
                        }
                        .tag("audio")
                    }
                    
                    // Subtitles Tab
                    if info.hasSubtitles {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(info.subtitleStreams.indices, id: \.self) { index in
                                    let stream = info.subtitleStreams[index]
                                    if info.subtitleStreams.count > 1 {
                                        InfoSection(title: "Subtitle Stream \(index + 1)") {
                                            if let title = stream.title {
                                                InfoRow(label: "Title", value: title)
                                            }
                                            if let language = stream.language {
                                                InfoRow(label: "Language", value: language)
                                            }
                                            if let encoding = stream.encoding {
                                                InfoRow(label: "Encoding", value: encoding)
                                            }
                                            if let forced = stream.forced {
                                                InfoRow(label: "Forced", value: forced ? "Yes" : "No")
                                            }
                                            if let isDefault = stream.`default` {
                                                InfoRow(label: "Default", value: isDefault ? "Yes" : "No")
                                            }
                                        }
                                    } else {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if let title = stream.title {
                                                InfoRow(label: "Title", value: title)
                                            }
                                            if let language = stream.language {
                                                InfoRow(label: "Language", value: language)
                                            }
                                            if let encoding = stream.encoding {
                                                InfoRow(label: "Encoding", value: encoding)
                                            }
                                            if let forced = stream.forced {
                                                InfoRow(label: "Forced", value: forced ? "Yes" : "No")
                                            }
                                            if let isDefault = stream.`default` {
                                                InfoRow(label: "Default", value: isDefault ? "Yes" : "No")
                                            }
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .tabItem {
                            Text("Subtitles")
                        }
                        .tag("subtitles")
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
    
    private func formatAudioCodec(_ codec: String) -> String {
        switch codec {
        case "E-AC-3":
            return "E-AC-3 (Dolby Digital Plus)"
        case "E-AC-3 JOC":
            return "E-AC-3 JOC (Dolby Atmos)"
        default:
            return codec
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale.current
        return formatter.string(from: date)
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
                .foregroundColor(.secondary)
                .frame(minWidth: 150, alignment: .trailing)
            
            Text(value)
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

struct SubtitleStreamInfo {
    let streamIndex: Int
    let codec: String?
    let encoding: String?
    let language: String?
    let title: String?
    let forced: Bool?
    let `default`: Bool?
}

// Extended media info structure for detailed view
struct DetailedMediaInfo {
    let format: String
    let fileSize: Int64
    let createdDate: Date?
    let modifiedDate: Date?
    let duration: Double?
    let overallBitRate: Int?
    let overallBitRateMode: String?
    let encodingApplication: String?
    let writingLibrary: String?
    
    let videoStreams: [VideoStreamInfo]
    let audioStreams: [AudioStreamInfo]
    let subtitleStreams: [SubtitleStreamInfo]
    
    var hasVideo: Bool { !videoStreams.isEmpty }
    var hasAudio: Bool { !audioStreams.isEmpty }
    var hasSubtitles: Bool { !subtitleStreams.isEmpty }
    
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
