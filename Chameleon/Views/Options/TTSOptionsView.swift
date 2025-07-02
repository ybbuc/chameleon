//
//  TTSOptionsView.swift
//  Chameleon
//
//  Created by Jakob Wells on 02.07.25.
//

import SwiftUI

struct TTSOptionsView: View {
    @Binding var ttsOptions: TTSOptions
    let ttsWrapper: TextToSpeechWrapper?
    
    @State private var availableVoices: [TextToSpeechWrapper.Voice] = []
    
    var body: some View {
        Form {
            // Language Selection
            HStack {
                Picker("Language:", selection: $ttsOptions.selectedLanguage) {
                    ForEach(TextToSpeechWrapper.Language.supportedLanguages, id: \.id) { language in
                        Text(language.displayName)
                            .tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: ttsOptions.selectedLanguage) { _, newLanguage in
                    // Reset voice selection when language changes
                    ttsOptions.selectedVoice = nil
                    loadVoicesForLanguage(newLanguage)
                }
                
                Spacer()
                    .frame(width: 82)
            }
            
            // Voice Selection
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Picker("Voice:", selection: Binding(
                        get: { ttsOptions.selectedVoice ?? availableVoices.first?.id ?? "" },
                        set: { ttsOptions.selectedVoice = $0 }
                    )) {
                        ForEach(availableVoices, id: \.id) { voice in
                            Text(voice.displayName)
                                .tag(voice.id)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .disabled(availableVoices.isEmpty || availableVoices.count == 1)
                    
                    // Preview button
                    Button(action: previewVoice) {
                        Image(systemName: "speaker.wave.2")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .disabled(availableVoices.isEmpty)
                    .help("Preview voice")
                    .frame(width: 74, alignment: .leading)
                }
            }
            
            // Speech Rate
            HStack {
                Picker("Speed:", selection: $ttsOptions.speechRate) {
                    Text("Very Slow").tag(120)
                    Text("Slow").tag(150)
                    Text("Normal").tag(180)
                    Text("Fast").tag(210)
                    Text("Very Fast").tag(240)
                    Text("Maximum").tag(270)
                }
                .pickerStyle(MenuPickerStyle())
                
                Text("\(ttsOptions.speechRate) WPM")
                    .monospacedDigit()
                    .frame(width: 74, alignment: .leading)
            }
        }
        .onAppear {
            loadVoicesForLanguage(ttsOptions.selectedLanguage)
        }
    }
    
    private func loadVoicesForLanguage(_ language: TextToSpeechWrapper.Language) {
        // Load hardcoded voices immediately (no async needed)
        availableVoices = TextToSpeechWrapper.Voice.voicesByLanguage[language.code] ?? []
        
        // If switching languages and no voice is selected, select the first one
        if ttsOptions.selectedVoice == nil && !availableVoices.isEmpty {
            ttsOptions.selectedVoice = availableVoices.first?.id
        }
        
        // If the currently selected voice is not available in the new language, reset it
        if let currentVoice = ttsOptions.selectedVoice,
           !availableVoices.contains(where: { $0.id == currentVoice }) {
            ttsOptions.selectedVoice = availableVoices.first?.id
        }
    }
    
    private func previewVoice() {
        guard let wrapper = ttsWrapper else { return }
        
        let voiceToPreview = ttsOptions.selectedVoice ?? availableVoices.first?.id
        guard let voice = voiceToPreview else { return }
        
        Task {
            do {
                // Use the sample text from the voice if available
                let sampleText = availableVoices.first(where: { $0.id == voice })?.sampleText
                try await wrapper.previewVoice(voice, text: sampleText, rate: ttsOptions.speechRate)
            } catch {
                // Voice preview failed silently
            }
        }
    }
}

#Preview {
    TTSOptionsView(
        ttsOptions: .constant(TTSOptions()),
        ttsWrapper: nil
    )
    .padding()
    .frame(width: 300)
}
