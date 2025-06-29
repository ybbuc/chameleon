//
//  OCROptionsView.swift
//  Chameleon
//
//  Created by Jakob Wells on 29.06.25.
//

import SwiftUI

struct OCROptionsView: View {
    @Binding var ocrOptions: OCRService.Options
    @Binding var ocrUseLanguageCorrection: Bool
    @Binding var ocrSelectedLanguage: String
    
    private var languageSelectionBinding: Binding<String> {
            Binding<String>(
                get: {
                    // Read the first language from the model, defaulting to "automatic".
                    ocrOptions.recognitionLanguages.first ?? "automatic"
                },
                set: { newLanguage in
                    // When the picker's value changes, update the model directly.
                    ocrOptions.recognitionLanguages = [newLanguage]
                }
            )
        }
    
    var body: some View {
            Form {
                Picker("Quality:", selection: $ocrOptions.recognitionLevel) {
                    ForEach(OCRService.RecognitionLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: ocrOptions.recognitionLevel) { _, newLevel in
                    // Disable language correction when switching to Fast
                    if newLevel == .fast {
                        ocrOptions.usesLanguageCorrection = false
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                Picker("Language:", selection: languageSelectionBinding) {
                    // Automatic option
                    Text("Automatic").tag("automatic")
                    
                    Divider()
                    
                    // Other language options
                    ForEach(OCRService.Language.supportedLanguages.filter { $0.id != "automatic" }, id: \.id) { language in
                        Text(language.displayName).tag(language.id)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: ocrSelectedLanguage) { _, newValue in
                    ocrOptions.recognitionLanguages = [newValue]
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                Toggle("Language Correction", isOn: $ocrOptions.usesLanguageCorrection)
                    .disabled(ocrOptions.recognitionLevel == .fast)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
    }
}
