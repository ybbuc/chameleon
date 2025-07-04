//
//  AudioPropertyDetector.swift
//  Chameleon
//
//  Detects audio properties using native macOS frameworks with FFmpeg fallback
//

import Foundation
import AVFoundation

struct AudioProperties {
    let sampleRate: Int?
    let channels: Int?
    let bitDepth: Int?
    let duration: TimeInterval?
    let codec: String?
    let bitRate: Int?
}

class AudioPropertyDetector {
    private let mediaInfoWrapper: MediaInfoWrapper?
    private let ffmpegWrapper: FFmpegWrapper?

    init(mediaInfoWrapper: MediaInfoWrapper? = nil, ffmpegWrapper: FFmpegWrapper? = nil) {
        self.mediaInfoWrapper = mediaInfoWrapper
        self.ffmpegWrapper = ffmpegWrapper
    }

    /// Detect audio properties using MediaInfoLib first, then AVFoundation, then FFmpeg as fallback
    func detectProperties(from url: URL) async throws -> AudioProperties {
        // First try MediaInfoLib if available
        if let mediaInfoWrapper = mediaInfoWrapper {
            do {
                return try detectWithMediaInfo(url: url, wrapper: mediaInfoWrapper)
            } catch {
                print("❌ AudioPropertyDetector: MediaInfoLib failed with error: \(error)")
                // Fall through to next method
            }
        } else {
            print("⚠️ AudioPropertyDetector: MediaInfoLib not available (wrapper initialization failed)")
        }
        
        // Try AVFoundation
        if let properties = await detectWithAVFoundation(url: url) {
            return properties
        }

        // Fall back to FFmpeg
        if let ffmpegWrapper = ffmpegWrapper {
            return try await detectWithFFmpeg(url: url, wrapper: ffmpegWrapper)
        }

        // No detection method available
        throw AudioDetectionError.noDetectionMethodAvailable
    }
    
    private func detectWithMediaInfo(url: URL, wrapper: MediaInfoWrapper) throws -> AudioProperties {
        print("🎵 AudioPropertyDetector: Using MediaInfoLib for \(url.lastPathComponent)")
        let mediaInfo = try wrapper.getFileInfo(url: url)
        
        // Only return properties if the file has audio
        guard mediaInfo.hasAudio else {
            throw AudioDetectionError.noAudioTrackFound
        }
        
        print("✅ AudioPropertyDetector: Successfully detected audio properties with MediaInfoLib")
        return AudioProperties(
            sampleRate: mediaInfo.audioSampleRate,
            channels: mediaInfo.audioChannels,
            bitDepth: mediaInfo.audioBitDepth,
            duration: mediaInfo.duration,
            codec: mediaInfo.audioCodec,
            bitRate: mediaInfo.audioBitRate
        )
    }

    private func detectWithAVFoundation(url: URL) async -> AudioProperties? {
        print("🎵 AudioPropertyDetector: Using AVFoundation for \(url.lastPathComponent)")
        let asset = AVAsset(url: url)

        // Check if asset is playable (indicates AVFoundation support)
        do {
            let isPlayable = try await asset.load(.isPlayable)
            guard isPlayable else { return nil }
        } catch {
            return nil
        }

        // Get audio tracks (works for both audio files and video files with audio)
        do {
            let tracks = try await asset.loadTracks(withMediaType: .audio)
            guard let audioTrack = tracks.first else {
                // No audio tracks found (could be video-only or unsupported)
                return nil
            }

            // Get format descriptions
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            guard let formatDescription = formatDescriptions.first else { return nil }

            // Extract audio properties
            let audioDesc = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)

            var bitDepth: Int?
            var codec: String?

            // Get bit depth from format info
            if let desc = audioDesc {
                let bytesPerFrame = desc.pointee.mBytesPerFrame
                let channelsPerFrame = desc.pointee.mChannelsPerFrame

                if channelsPerFrame > 0 && bytesPerFrame > 0 {
                    let bytesPerSample = Int(bytesPerFrame) / Int(channelsPerFrame)
                    bitDepth = bytesPerSample * 8
                }

                // Determine codec from format ID
                let formatID = desc.pointee.mFormatID
                codec = fourCCString(from: formatID)

                // For video files, bit depth might not be accurate from format flags
                // Common video audio tracks use 16-bit PCM or compressed formats
                if let depth = bitDepth, depth == 0 || depth > 32 {
                    bitDepth = nil // Let FFmpeg detect it
                }
            }

            // Get sample rate
            let sampleRate: Int? = if let desc = audioDesc {
                Int(desc.pointee.mSampleRate)
            } else {
                nil
            }

            // Get channels
            let channels: Int? = if let desc = audioDesc {
                Int(desc.pointee.mChannelsPerFrame)
            } else {
                nil
            }

            // Get duration
            let duration = try? await asset.load(.duration).seconds

            print("✅ AudioPropertyDetector: Successfully detected audio properties with AVFoundation")
            return AudioProperties(
                sampleRate: sampleRate,
                channels: channels,
                bitDepth: bitDepth,
                duration: duration,
                codec: codec,
                bitRate: nil  // AVFoundation doesn't provide bit rate info easily
            )
        } catch {
            return nil
        }
    }

    private func detectWithFFmpeg(url: URL, wrapper: FFmpegWrapper) async throws -> AudioProperties {
        print("🎵 AudioPropertyDetector: Using FFmpeg for \(url.lastPathComponent)")
        let mediaInfo = try await wrapper.getMediaInfo(url: url)

        print("✅ AudioPropertyDetector: Successfully detected audio properties with FFmpeg")
        return AudioProperties(
            sampleRate: mediaInfo.audioSampleRate,
            channels: mediaInfo.audioChannels,
            bitDepth: mediaInfo.audioBitDepth,
            duration: mediaInfo.duration,
            codec: mediaInfo.audioCodec,
            bitRate: mediaInfo.audioBitRate
        )
    }

    private func fourCCString(from formatID: AudioFormatID) -> String? {
        let bytes = [
            UInt8((formatID >> 24) & 0xFF),
            UInt8((formatID >> 16) & 0xFF),
            UInt8((formatID >> 8) & 0xFF),
            UInt8(formatID & 0xFF)
        ]

        // Check if it's a printable string
        if bytes.allSatisfy({ $0 >= 32 && $0 < 127 }) {
            return String(bytes: bytes, encoding: .ascii)
        }

        // Otherwise, check known format IDs
        switch formatID {
        case kAudioFormatLinearPCM:
            return "pcm"
        case kAudioFormatMPEG4AAC:
            return "aac"
        case kAudioFormatMPEGLayer3:
            return "mp3"
        case kAudioFormatAppleLossless:
            return "alac"
        case kAudioFormatFLAC:
            return "flac"
        default:
            return nil
        }
    }
}

enum AudioDetectionError: LocalizedError {
    case noDetectionMethodAvailable
    case noAudioTrackFound

    var errorDescription: String? {
        switch self {
        case .noDetectionMethodAvailable:
            return "No audio detection method available"
        case .noAudioTrackFound:
            return "No audio track found in file"
        }
    }
}
