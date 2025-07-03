//
//  TextToSpeechWrapper.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import Foundation

class TextToSpeechWrapper {
    private let sayPath = "/usr/bin/say"
    private var currentProcess: Process?

    enum TTSError: LocalizedError {
        case sayCommandNotFound
        case textFileReadError
        case conversionFailed(String)
        case cancelled

        var errorDescription: String? {
            switch self {
            case .sayCommandNotFound:
                return "macOS text-to-speech command not found"
            case .textFileReadError:
                return "Failed to read text file"
            case .conversionFailed(let message):
                return "Text-to-speech conversion failed: \(message)"
            case .cancelled:
                return "Text-to-speech conversion was cancelled"
            }
        }
    }

    struct Voice: Identifiable, Hashable {
        let id: String
        let name: String
        let language: String
        let languageCode: String
        let sampleText: String

        var displayName: String {
            return name
        }

        // Hardcoded voices for each language
        static let voicesByLanguage: [String: [Voice]] = [
            "en": [
                Voice(id: "Alex", name: "Alex", language: "en", languageCode: "en_US", sampleText: "Hello, my name is Alex."),
                Voice(id: "Daniel", name: "Daniel", language: "en", languageCode: "en_GB", sampleText: "Hello, my name is Daniel."),
                Voice(id: "Fred", name: "Fred", language: "en", languageCode: "en_US", sampleText: "Hello, my name is Fred."),
                Voice(id: "Karen", name: "Karen", language: "en", languageCode: "en_AU", sampleText: "Hello, my name is Karen."),
                Voice(id: "Moira", name: "Moira", language: "en", languageCode: "en_IE", sampleText: "Hello, my name is Moira."),
                Voice(id: "Rishi", name: "Rishi", language: "en", languageCode: "en_IN", sampleText: "Hello, my name is Rishi."),
                Voice(id: "Samantha", name: "Samantha", language: "en", languageCode: "en_US", sampleText: "Hello, my name is Samantha."),
                Voice(id: "Victoria", name: "Victoria", language: "en", languageCode: "en_US", sampleText: "Hello, my name is Victoria.")
            ],
            "es": [
                Voice(id: "Mónica", name: "Mónica", language: "es", languageCode: "es_ES", sampleText: "¡Hola! Me llamo Mónica."),
                Voice(id: "Paulina", name: "Paulina", language: "es", languageCode: "es_MX", sampleText: "¡Hola! Me llamo Paulina.")
            ],
            "fr": [
                Voice(id: "Amélie", name: "Amélie", language: "fr", languageCode: "fr_CA", sampleText: "Bonjour! Je m'appelle Amélie."),
                Voice(id: "Jacques", name: "Jacques", language: "fr", languageCode: "fr_FR", sampleText: "Bonjour, je m'appelle Jacques."),
                Voice(id: "Thomas", name: "Thomas", language: "fr", languageCode: "fr_FR", sampleText: "Bonjour, je m'appelle Thomas.")
            ],
            "de": [
                Voice(id: "Anna", name: "Anna", language: "de", languageCode: "de_DE", sampleText: "Hallo! Ich heiße Anna.")
            ],
            "it": [
                Voice(id: "Alice", name: "Alice", language: "it", languageCode: "it_IT", sampleText: "Ciao! Mi chiamo Alice.")
            ],
            "pt": [
                Voice(id: "Joana", name: "Joana", language: "pt", languageCode: "pt_PT", sampleText: "Olá! Chamo‑me Joana."),
                Voice(id: "Luciana", name: "Luciana", language: "pt", languageCode: "pt_BR", sampleText: "Olá, meu nome é Luciana.")
            ],
            "nl": [
                Voice(id: "Ellen", name: "Ellen", language: "nl", languageCode: "nl_BE", sampleText: "Hallo! Mijn naam is Ellen."),
                Voice(id: "Xander", name: "Xander", language: "nl", languageCode: "nl_NL", sampleText: "Hallo! Mijn naam is Xander.")
            ],
            "sv": [
                Voice(id: "Alva", name: "Alva", language: "sv", languageCode: "sv_SE", sampleText: "Hej! Jag heter Alva.")
            ],
            "no": [
                Voice(id: "Nora", name: "Nora", language: "no", languageCode: "nb_NO", sampleText: "Hei! Jeg heter Nora.")
            ],
            "da": [
                Voice(id: "Sara", name: "Sara", language: "da", languageCode: "da_DK", sampleText: "Hej! Jeg hedder Sara.")
            ],
            "fi": [
                Voice(id: "Satu", name: "Satu", language: "fi", languageCode: "fi_FI", sampleText: "Hei! Nimeni on Satu.")
            ],
            "ru": [
                Voice(id: "Milena", name: "Milena", language: "ru", languageCode: "ru_RU", sampleText: "Здравствуйте! Меня зовут Милена.")
            ],
            "pl": [
                Voice(id: "Zosia", name: "Zosia", language: "pl", languageCode: "pl_PL", sampleText: "Hi my name is Zosia")
            ],
            "tr": [
                Voice(id: "Yelda", name: "Yelda", language: "tr", languageCode: "tr_TR", sampleText: "Merhaba, benim adım Yelda.")
            ],
            "ar": [
                Voice(id: "Majed", name: "Majed", language: "ar", languageCode: "ar_001", sampleText: "مرحبًا! اسمي ماجد.")
            ],
            "he": [
                Voice(id: "Carmit", name: "Carmit", language: "he", languageCode: "he_IL", sampleText: "שלום, שמי כרמית.")
            ],
            "hi": [
                Voice(id: "Lekha", name: "Lekha", language: "hi", languageCode: "hi_IN", sampleText: "नमस्ते, मेरा नाम लेखा है।")
            ],
            "zh": [
                Voice(id: "Meijia", name: "Meijia", language: "zh", languageCode: "zh_TW", sampleText: "你好，我叫美佳。"),
                Voice(id: "Sinji", name: "Sinji", language: "zh", languageCode: "zh_HK", sampleText: "你好！我叫善怡。"),
                Voice(id: "Tingting", name: "Tingting", language: "zh", languageCode: "zh_CN", sampleText: "你好！我叫婷婷。")
            ],
            "ja": [
                Voice(id: "Kyoko", name: "Kyoko", language: "ja", languageCode: "ja_JP", sampleText: "こんにちは! 私の名前はKyokoです。")
            ],
            "ko": [
                Voice(id: "Yuna", name: "Yuna", language: "ko", languageCode: "ko_KR", sampleText: "안녕하세요, 제 이름은 유나입니다.")
            ]
        ]
    }

    struct Language: Identifiable, Hashable {
        let id: String
        let displayName: String
        let code: String

        static let supportedLanguages: [Language] = {
            // Only include languages that have voices defined
            let languagesWithVoices = Set(Voice.voicesByLanguage.keys)
            let allLanguages = [
                Language(id: "en", displayName: "English", code: "en"),
                Language(id: "es", displayName: "Spanish", code: "es"),
                Language(id: "fr", displayName: "French", code: "fr"),
                Language(id: "de", displayName: "German", code: "de"),
                Language(id: "it", displayName: "Italian", code: "it"),
                Language(id: "pt", displayName: "Portuguese", code: "pt"),
                Language(id: "nl", displayName: "Dutch", code: "nl"),
                Language(id: "sv", displayName: "Swedish", code: "sv"),
                Language(id: "no", displayName: "Norwegian", code: "no"),
                Language(id: "da", displayName: "Danish", code: "da"),
                Language(id: "fi", displayName: "Finnish", code: "fi"),
                Language(id: "ru", displayName: "Russian", code: "ru"),
                Language(id: "pl", displayName: "Polish", code: "pl"),
                Language(id: "tr", displayName: "Turkish", code: "tr"),
                Language(id: "ar", displayName: "Arabic", code: "ar"),
                Language(id: "he", displayName: "Hebrew", code: "he"),
                Language(id: "hi", displayName: "Hindi", code: "hi"),
                Language(id: "zh", displayName: "Chinese", code: "zh"),
                Language(id: "ja", displayName: "Japanese", code: "ja"),
                Language(id: "ko", displayName: "Korean", code: "ko")
            ]
            return allLanguages.filter { languagesWithVoices.contains($0.id) }
        }()
    }

    init() throws {
        // Verify say command exists
        guard FileManager.default.fileExists(atPath: sayPath) else {
            throw TTSError.sayCommandNotFound
        }
    }

    func getAvailableVoices() async throws -> [Voice] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sayPath)
        process.arguments = ["-v", "?"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return []
        }

        var voices: [Voice] = []
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            guard !line.isEmpty else { continue }

            // Parse voice line format: "Name               lang_CODE    # Sample text"
            let components = line.split(separator: "#", maxSplits: 1)
            guard components.count == 2 else { continue }

            let voiceInfo = components[0].trimmingCharacters(in: .whitespaces)
            let sampleText = components[1].trimmingCharacters(in: .whitespaces)

            // Extract name and language code
            let voiceComponents = voiceInfo.split(separator: " ", omittingEmptySubsequences: true)
            guard voiceComponents.count >= 2 else { continue }

            // Handle voices with parenthetical descriptions
            var name = String(voiceComponents[0])
            let languageCode = String(voiceComponents[voiceComponents.count - 1])

            // Some voices have descriptions like "Eddy (English (UK))"
            if voiceComponents.count > 2 && name != "Bad" && name != "Good" {
                // Reconstruct the full name
                let endIndex = voiceComponents.count - 1
                name = voiceComponents[0..<endIndex].joined(separator: " ")
            }

            // Extract language from language code (e.g., "en_US" -> "en")
            let language = String(languageCode.split(separator: "_").first ?? "")

            let voice = Voice(
                id: name,
                name: name,
                language: language,
                languageCode: languageCode,
                sampleText: sampleText
            )

            voices.append(voice)
        }

        return voices
    }

    func getVoicesForLanguage(_ language: Language) async throws -> [Voice] {
        // Return hardcoded voices for the language
        return Voice.voicesByLanguage[language.code] ?? []
    }

    func convertTextToSpeech(
        inputURL: URL,
        outputURL: URL,
        format: TTSFormat,
        voice: String? = nil,
        rate: Int = 180
    ) async throws {
        // Verify the input file exists and is readable
        guard FileManager.default.fileExists(atPath: inputURL.path) else {
            throw TTSError.textFileReadError
        }

        // Create the process
        let process = Process()
        currentProcess = process

        process.executableURL = URL(fileURLWithPath: sayPath)

        var arguments: [String] = []

        // Add voice if specified
        if let voice = voice {
            arguments.append(contentsOf: ["-v", voice])
        }

        // Add speech rate
        arguments.append(contentsOf: ["-r", String(rate)])

        // Add output file and format
        arguments.append(contentsOf: ["-o", outputURL.path])

        // Add file format arguments
        switch format {
        case .aiff:
            arguments.append(contentsOf: ["--file-format=AIFF"])
        case .m4a:
            arguments.append(contentsOf: ["--file-format=m4af", "--data-format=aac"])
        case .wav:
            arguments.append(contentsOf: ["--file-format=WAVE"])
        case .caf:
            arguments.append(contentsOf: ["--file-format=caff"])
        }

        // Use -f flag to read from file instead of passing text as argument
        arguments.append(contentsOf: ["-f", inputURL.path])

        process.arguments = arguments

        // Set up pipes for error handling
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()

            // Wait for completion in a cancellable way
            await withCheckedContinuation { continuation in
                DispatchQueue.global().async {
                    process.waitUntilExit()
                    continuation.resume()
                }
            }

            if process.terminationStatus != 0 {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                throw TTSError.conversionFailed(errorMessage)
            }
        } catch {
            if (error as NSError).code == 15 { // Process was terminated
                throw TTSError.cancelled
            }
            throw error
        }
    }

    func cancel() {
        currentProcess?.terminate()
        currentProcess = nil
    }

    func previewVoice(_ voice: String, text: String? = nil, rate: Int? = nil) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sayPath)

        var arguments = ["-v", voice]

        // Add speech rate if provided
        if let rate = rate {
            arguments.append(contentsOf: ["-r", "\(rate)"])
        }

        // Use provided text or default sample
        let previewText = text ?? "Hello, this is a preview of the \(voice) voice."
        arguments.append(previewText)

        process.arguments = arguments
        process.standardOutput = Pipe()
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()
    }
}

// TTS output format options
enum TTSFormat: String, CaseIterable {
    case aiff = "aiff"
    case m4a = "m4a"
    case wav = "wav"
    case caf = "caf"

    var displayName: String {
        return rawValue.uppercased()
    }

    var fileExtension: String {
        return rawValue
    }

    var description: String? {
        switch self {
        case .aiff:
            return "Audio Interchange File Format"
        case .m4a:
            return "MPEG-4 Audio (AAC)"
        case .wav:
            return "Waveform Audio"
        case .caf:
            return "Core Audio Format"
        }
    }
}
