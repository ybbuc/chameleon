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
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Spacer()
                Picker("Quality", selection: $ocrOptions.recognitionLevel) {
                    ForEach(OCRService.RecognitionLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }
            
            HStack {
                Spacer()
                Picker("Language", selection: $ocrSelectedLanguage) {
                    ForEach(OCRService.Language.supportedLanguages, id: \.id) { language in
                        Text(language.displayName).tag(language.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 250)
                .onChange(of: ocrSelectedLanguage) { oldValue, newValue in
                    print("Language selection changed from '\(oldValue)' to '\(newValue)'")
                    ocrOptions.recognitionLanguages = [newValue]
                }
            }
            
            HStack {
                Spacer()
                Toggle("Language Correction", isOn: $ocrUseLanguageCorrection)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: ocrUseLanguageCorrection) { _, newValue in
                        ocrOptions.usesLanguageCorrection = newValue
                    }
            }
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
