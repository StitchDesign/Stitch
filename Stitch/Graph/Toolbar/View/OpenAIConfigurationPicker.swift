//
//  OpenAIConfigurationPicker.swift
//  Stitch
//
//  Created by Claude on 8/14/25.
//

import SwiftUI

struct OpenAIConfigurationPicker: View {
    @Bindable var document: StitchDocumentViewModel
    
    // AI Configuration - Persisted via @AppStorage
    @AppStorage(StitchAppSettings.OPENAI_MODEL.rawValue)
    private var openaiModel: OpenAIModel = OpenAIModel.gpt5Mini
    
    @AppStorage(StitchAppSettings.OPENAI_VERBOSITY.rawValue) 
    private var openaiVerbosity: OpenAIVerbosity = .low
    
    @AppStorage(StitchAppSettings.OPENAI_REASONING_EFFORT.rawValue) 
    private var openaiReasoningEffort: OpenAIReasoningEffort = .medium
    
    @AppStorage(StitchAppSettings.CLAUDE_MODEL.rawValue)
    private var claudeModel: ClaudeModel = .claude4Sonnet
    
    @AppStorage(StitchAppSettings.AI_PROVIDER.rawValue)
    private var aiProvider: AIProvider = .openAI

    var currentModelDisplayName: String {
        self.aiProvider.displayName
    }

    var body: some View {
        Menu {
            if self.aiProvider == .openAI {
                Section("OpenAI Model") {
                    ForEach(OpenAIModel.allCases) { model in
                        Button(action: {
                            openaiModel = model
                            log("🎯 OpenAI Model changed to: \(model.rawValue)")
                        }) {
                            HStack {
                                Text(model.displayName)
                                if openaiModel == model {
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
                            openaiVerbosity = verbosity
                            log("🎯 Verbosity changed to: \(verbosity.rawValue)")
                        }) {
                            HStack {
                                Text(verbosity.displayName)
                                if openaiVerbosity == verbosity {
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
                            openaiReasoningEffort = effort
                            log("🎯 Reasoning Effort changed to: \(effort.rawValue)")
                        }) {
                            HStack {
                                Text(effort.displayName)
                                if openaiReasoningEffort == effort {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } else {
                Section("Claude Model") {
                    ForEach(ClaudeModel.allCases) { model in
                        Button(action: {
                            claudeModel = model
                            log("🎯 Claude Model changed to: \(model.rawValue)")
                        }) {
                            HStack {
                                Text(model.displayName)
                                if claudeModel == model {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            Button(action: { }) {
                Text(currentModelDisplayName)
                    .lineLimit(1)
//                    .frame(width: 300)
//                    .frame(width: 180)
//                    .frame(width: 80)
            }
        }
//        .modifier(iPadTopBarButtonStyle())
//        .frame(width: 300)
//        .frame(width: 180)
//        .frame(width: 80)
    }
}
