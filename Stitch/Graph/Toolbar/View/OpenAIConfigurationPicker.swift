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
    private var openaiModel: String = OpenAIModel.gpt5Mini.rawValue
    
    @AppStorage(StitchAppSettings.OPENAI_VERBOSITY.rawValue) 
    private var openaiVerbosity: String = "low"
    
    @AppStorage(StitchAppSettings.OPENAI_REASONING_EFFORT.rawValue) 
    private var openaiReasoningEffort: String = "medium"
    
    @AppStorage(StitchAppSettings.CLAUDE_MODEL.rawValue)
    private var claudeModel: String = "claude-3-5-sonnet-20241022"
    
    @State private var currentProvider = AIProviderConfig.shared.currentProvider
    
    var body: some View {
        Menu {
            if currentProvider == .openAI {
                Section("OpenAI Model") {
                    ForEach(OpenAIModel.allCases) { model in
                        Button(action: {
                            openaiModel = model.rawValue
                            log("🎯 OpenAI Model changed to: \(model.rawValue)")
                        }) {
                            HStack {
                                Text(model.displayName)
                                if openaiModel == model.rawValue {
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
                            openaiVerbosity = verbosity.rawValue
                            log("🎯 Verbosity changed to: \(verbosity.rawValue)")
                        }) {
                            HStack {
                                Text(verbosity.displayName)
                                if openaiVerbosity == verbosity.rawValue {
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
                            openaiReasoningEffort = effort.rawValue
                            log("🎯 Reasoning Effort changed to: \(effort.rawValue)")
                        }) {
                            HStack {
                                Text(effort.displayName)
                                if openaiReasoningEffort == effort.rawValue {
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
                            claudeModel = model.rawValue
                            log("🎯 Claude Model changed to: \(model.rawValue)")
                        }) {
                            HStack {
                                Text(model.displayName)
                                if claudeModel == model.rawValue {
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
                Image(systemName: "gear")
            }
        }
        .modifier(iPadTopBarButtonStyle())
        .onAppear {
            currentProvider = AIProviderConfig.shared.currentProvider
        }
        .onReceive(NotificationCenter.default.publisher(for: .init("AIProviderChanged"))) { _ in
            currentProvider = AIProviderConfig.shared.currentProvider
        }
    }
}
