//
//  OpenAIConfigurationPicker.swift
//  Stitch
//
//  Created by Claude on 8/14/25.
//

import SwiftUI

struct OpenAIConfigurationPicker: View {
    @Bindable var document: StitchDocumentViewModel
    
    var body: some View {
        Menu {
            Section("Model") {
                ForEach(OpenAIModel.allCases) { model in
                    Button(action: {
                        document.openaiModel = model.rawValue
                    }) {
                        HStack {
                            Text(model.displayName)
                            if document.openaiModel == model.rawValue {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Section("Verbosity") {
                ForEach(OpenAIVerbosity.allCases) { verbosity in
                    Button(action: {
                        document.openaiVerbosity = verbosity.rawValue
                    }) {
                        HStack {
                            Text(verbosity.displayName)
                            if document.openaiVerbosity == verbosity.rawValue {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            Section("Reasoning Effort") {
                ForEach(OpenAIReasoningEffort.allCases) { effort in
                    Button(action: {
                        document.openaiReasoningEffort = effort.rawValue
                    }) {
                        HStack {
                            Text(effort.displayName)
                            if document.openaiReasoningEffort == effort.rawValue {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Button(action: { }) {
                Image(systemName: "gear")
            }
        }
        .modifier(iPadTopBarButtonStyle())
    }
}

struct CompactOpenAIConfigurationIndicator: View {
    @Bindable var document: StitchDocumentViewModel
    
    var modelShortName: String {
        document.openaiModel.asOpenAIModel.displayName
    }
    
    var verbosityInitial: String {
        String(document.openaiVerbosity.asOpenAIVerbosity.displayName.prefix(1))
    }
    
    var reasoningEffortInitial: String {
        String(document.openaiReasoningEffort.asOpenAIReasoningEffort.displayName.prefix(1))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(modelShortName)
                .font(.caption2)
                .fontWeight(.medium)
            HStack(spacing: 4) {
                Text("V:\(verbosityInitial)")
                    .font(.caption2)
                Text("R:\(reasoningEffortInitial)")
                    .font(.caption2)
            }
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(6)
    }
}