//
//  OpenAIConfigurationPicker.swift
//  Stitch
//
//  Created by Claude on 8/14/25.
//

import SwiftUI

struct OpenAIConfigurationPicker: View {
    @Bindable var document: StitchDocumentViewModel
    
    // OpenAI Configuration - Persisted via @AppStorage
    @AppStorage(StitchAppSettings.OPENAI_MODEL.rawValue) 
    private var openaiModel: String = "gpt-5-2025-08-07"
    
    @AppStorage(StitchAppSettings.OPENAI_VERBOSITY.rawValue) 
    private var openaiVerbosity: String = "low"
    
    @AppStorage(StitchAppSettings.OPENAI_REASONING_EFFORT.rawValue) 
    private var openaiReasoningEffort: String = "medium"
    
    var body: some View {
        Menu {
            Section("Model") {
                ForEach(OpenAIModel.allCases) { model in
                    Button(action: {
                        openaiModel = model.rawValue
                        log("🎯 Model changed to: \(model.rawValue)")
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
        } label: {
            Button(action: { }) {
                Image(systemName: "gear")
            }
        }
        .modifier(iPadTopBarButtonStyle())
    }
}
