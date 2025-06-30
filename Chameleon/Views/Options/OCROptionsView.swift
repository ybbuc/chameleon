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
            .onChange(of: ocrOptions.recognitionLevel) { _, newLevel in
                // Disable language correction when switching to Fast
                if newLevel == .fast {
                    ocrOptions.usesLanguageCorrection = false
                }
            }
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
            
            Toggle("Language Correction", isOn: $ocrOptions.usesLanguageCorrection)
                .disabled(ocrOptions.recognitionLevel == .fast)
                .onChange(of: ocrOptions.usesLanguageCorrection) { _, newValue in
                    ocrUseLanguageCorrection = newValue
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
        .onAppear {
            // Ensure initial sync
            if ocrOptions.recognitionLanguages.first != ocrSelectedLanguage {
                ocrOptions.recognitionLanguages = [ocrSelectedLanguage]
            }
            if ocrOptions.usesLanguageCorrection != ocrUseLanguageCorrection {
                ocrOptions.usesLanguageCorrection = ocrUseLanguageCorrection
            }
        }
    }
}
