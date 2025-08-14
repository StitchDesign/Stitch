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
                        print("🎯 Model changed to: \(model.rawValue)")
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
                        print("🎯 Verbosity changed to: \(verbosity.rawValue)")
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
                        print("🎯 Reasoning Effort changed to: \(effort.rawValue)")
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