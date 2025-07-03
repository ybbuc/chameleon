//
//  TTSOptions.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import Foundation

struct TTSOptions {
    var selectedLanguage: TextToSpeechWrapper.Language = TextToSpeechWrapper.Language.defaultLanguage
    var selectedVoice: String? = "Samantha"  // Default to Samantha for English
    var speechRate: Int = 180
    var format: TTSFormat = .m4a
}
