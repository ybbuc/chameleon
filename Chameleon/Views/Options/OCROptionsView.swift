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
    
    var body: some View {
            Form {
                Picker("Quality:", selection: $ocrOptions.recognitionLevel) {
                    ForEach(OCRService.RecognitionLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .transition(.opacity.combined(with: .move(edge: .top)))
                
                Picker("Language:", selection: $ocrSelectedLanguage) {
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
                
                Toggle("Language Correction", isOn: $ocrUseLanguageCorrection)
                    .onChange(of: ocrUseLanguageCorrection) { _, newValue in
                        ocrOptions.usesLanguageCorrection = newValue
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            .onAppear {
                // Verify that the selected language exists in the supported languages
                let supportedLanguages = OCRService.Language.supportedLanguages
                let supportedCodes = supportedLanguages.map { $0.id }
                
                // If the current selection is not in the supported list, reset to automatic
                if !supportedCodes.contains(ocrSelectedLanguage) {
                    ocrSelectedLanguage = "automatic"
                    ocrOptions.recognitionLanguages = ["automatic"]
                } else {
                    // Ensure ocrOptions is synced with the current selection
                    ocrOptions.recognitionLanguages = [ocrSelectedLanguage]
                }
            }
    }
}
