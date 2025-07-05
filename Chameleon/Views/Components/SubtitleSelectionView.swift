//
//  SubtitleSelectionView.swift
//  Chameleon
//
//  Created by Jakob Wells on 04.07.25.
//

import SwiftUI

struct SubtitleSelectionView: View {
    let subtitleStreams: [SubtitleStreamInfo]
    @Binding var selectedSubtitles: Set<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Subtitles")
                    .font(.headline)
                
                Spacer()
                
                Button("Select All") {
                    selectedSubtitles = Set(subtitleStreams.map { $0.streamIndex })
                }
                .controlSize(.small)
                
                Button("Deselect All") {
                    selectedSubtitles.removeAll()
                }
                .controlSize(.small)
            }
            .padding(.bottom, 4)
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(subtitleStreams, id: \.streamIndex) { subtitle in
                    SubtitleRow(
                        subtitle: subtitle,
                        isSelected: selectedSubtitles.contains(subtitle.streamIndex)
                    ) { isSelected in
                        if isSelected {
                            selectedSubtitles.insert(subtitle.streamIndex)
                        } else {
                            selectedSubtitles.remove(subtitle.streamIndex)
                        }
                    }
                }
            }
        }
        .padding()
        .frame(minWidth: 300, maxWidth: 400)
    }
}

struct SubtitleRow: View {
    let subtitle: SubtitleStreamInfo
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle(subtitleLabel, isOn: Binding(
                get: { isSelected },
                set: { onToggle($0) }
            ))
            .toggleStyle(.checkbox)
            
            // Only show language if it's not already in the subtitle label
            if let language = subtitle.language,
               !language.isEmpty,
               !subtitleLabel.localizedCaseInsensitiveContains(language) {
                Text(language)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let encoding = subtitle.encoding {
                Text(encoding)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
//            if subtitle.forced == true {
//                Text("Forced")
//                    .font(.caption2)
//                    .fontWeight(.medium)
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 6)
//                    .padding(.vertical, 2)
//                    .background(Color.orange)
//                    .cornerRadius(4)
//            }
//            
//            if subtitle.`default` == true {
//                Text("Default")
//                    .font(.caption2)
//                    .fontWeight(.medium)
//                    .foregroundColor(.white)
//                    .padding(.horizontal, 6)
//                    .padding(.vertical, 2)
//                    .background(Color.blue)
//                    .cornerRadius(4)
//            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(!isSelected)
        }
    }
    
    private var subtitleLabel: String {
        let trackNumber = subtitle.streamIndex + 1
        
        if let title = subtitle.title, !title.isEmpty {
            return "\(trackNumber): \(title)"
        } else if let language = subtitle.language, !language.isEmpty {
            return "\(trackNumber): \(language)"
        } else {
            return "\(trackNumber)"
        }
    }
}
