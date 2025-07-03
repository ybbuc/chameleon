//
//  TextToSpeechTests.swift
//  ChameleonTests
//
//  Created by Jakob Wells on 03.07.25.
//

import Testing
import Foundation
@testable import Chameleon

struct TextToSpeechTests {

    // System voice info parsed from say command
    struct SystemVoice {
        let name: String
        let languageCode: String
        let sampleText: String
    }

    // Parse the output of `say -v ?` command
    private func getSystemVoices() throws -> [SystemVoice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = ["-v", "?"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw TestError("Failed to query system voices")
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            throw TestError("Failed to parse voice output")
        }

        var voices: [SystemVoice] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            guard !line.isEmpty else { continue }

            // Skip voices with parentheses (like "Eddy (French (France))")
            if line.contains("(") && line.contains(")") {
                continue
            }

            // Parse format: "Name               lang_CODE    # Sample text"
            let components = line.split(separator: "#", maxSplits: 1)
            guard components.count == 2 else { continue }

            let voiceInfo = components[0].trimmingCharacters(in: .whitespaces)
            let sampleText = components[1].trimmingCharacters(in: .whitespaces)

            // Extract name and language code
            let voiceComponents = voiceInfo.split(separator: " ", omittingEmptySubsequences: true)
            guard voiceComponents.count >= 2 else { continue }

            let name = String(voiceComponents[0])
            let languageCode = String(voiceComponents[voiceComponents.count - 1])

            voices.append(SystemVoice(
                name: name,
                languageCode: languageCode,
                sampleText: sampleText
            ))
        }

        return voices
    }

    @Test
    func testAllConfiguredVoicesExistOnSystem() async throws {
        guard let wrapper = try? TextToSpeechWrapper() else {
            throw TestSkipError("TextToSpeechWrapper not available")
        }

        let systemVoices = try getSystemVoices()
        let systemVoiceNames = Set(systemVoices.map { $0.name })

        var missingVoices: [(language: String, voice: String)] = []

        // Check each configured voice
        for (language, voices) in TextToSpeechWrapper.Voice.voicesByLanguage {
            for voice in voices {
                if !systemVoiceNames.contains(voice.id) {
                    missingVoices.append((language: language, voice: voice.id))
                }
            }
        }

        if !missingVoices.isEmpty {
            let missingList = missingVoices.map { "\($0.language): \($0.voice)" }.joined(separator: "\n")
            Issue.record("The following configured voices do not exist on this system:\n\(missingList)")
        }

        #expect(missingVoices.isEmpty, "All configured voices should exist on the system")
    }

    @Test
    func testConfiguredVoiceSampleTextMatches() async throws {
        guard let wrapper = try? TextToSpeechWrapper() else {
            throw TestSkipError("TextToSpeechWrapper not available")
        }

        let systemVoices = try getSystemVoices()
        let systemVoiceMap = Dictionary(uniqueKeysWithValues: systemVoices.map { ($0.name, $0) })

        var mismatchedSamples: [(voice: String, configured: String, system: String)] = []

        // Check sample text for each configured voice
        for (_, voices) in TextToSpeechWrapper.Voice.voicesByLanguage {
            for voice in voices {
                if let systemVoice = systemVoiceMap[voice.id] {
                    if voice.sampleText != systemVoice.sampleText {
                        mismatchedSamples.append((
                            voice: voice.id,
                            configured: voice.sampleText,
                            system: systemVoice.sampleText
                        ))
                    }
                }
            }
        }

        if !mismatchedSamples.isEmpty {
            let mismatchList = mismatchedSamples.map {
                "\($0.voice):\n  Configured: \($0.configured)\n  System: \($0.system)"
            }.joined(separator: "\n\n")
            Issue.record("The following voices have mismatched sample text:\n\(mismatchList)")
        }

        #expect(mismatchedSamples.isEmpty, "All voice sample texts should match the system")
    }

    @Test
    func testConfiguredVoiceLanguageCodesMatch() async throws {
        guard let wrapper = try? TextToSpeechWrapper() else {
            throw TestSkipError("TextToSpeechWrapper not available")
        }

        let systemVoices = try getSystemVoices()
        let systemVoiceMap = Dictionary(uniqueKeysWithValues: systemVoices.map { ($0.name, $0) })

        var mismatchedCodes: [(voice: String, configured: String, system: String)] = []

        // Check language codes for each configured voice
        for (_, voices) in TextToSpeechWrapper.Voice.voicesByLanguage {
            for voice in voices {
                if let systemVoice = systemVoiceMap[voice.id] {
                    if voice.languageCode != systemVoice.languageCode {
                        mismatchedCodes.append((
                            voice: voice.id,
                            configured: voice.languageCode,
                            system: systemVoice.languageCode
                        ))
                    }
                }
            }
        }

        if !mismatchedCodes.isEmpty {
            let mismatchList = mismatchedCodes.map {
                "\($0.voice): configured=\($0.configured), system=\($0.system)"
            }.joined(separator: "\n")
            Issue.record("The following voices have mismatched language codes:\n\(mismatchList)")
        }

        #expect(mismatchedCodes.isEmpty, "All voice language codes should match the system")
    }

    @Test
    func testReportUnconfiguredSystemVoices() async throws {
        guard let wrapper = try? TextToSpeechWrapper() else {
            throw TestSkipError("TextToSpeechWrapper not available")
        }

        let systemVoices = try getSystemVoices()
        let configuredVoiceNames = Set(
            TextToSpeechWrapper.Voice.voicesByLanguage.values
                .flatMap { $0 }
                .map { $0.id }
        )

        var unconfiguredVoices: [SystemVoice] = []

        for systemVoice in systemVoices {
            if !configuredVoiceNames.contains(systemVoice.name) {
                unconfiguredVoices.append(systemVoice)
            }
        }

        if !unconfiguredVoices.isEmpty {
            let voiceList = unconfiguredVoices.map {
                "\($0.name) (\($0.languageCode)): \($0.sampleText)"
            }.joined(separator: "\n")
            print("The following system voices are not configured in the app:\n\(voiceList)")
        }

        // This test always passes - it's just for reporting
        #expect(true, "Successfully reported unconfigured voices")
    }
}

// Helper error types
struct TestError: Error {
    let message: String
    init(_ message: String) {
        self.message = message
    }
}
