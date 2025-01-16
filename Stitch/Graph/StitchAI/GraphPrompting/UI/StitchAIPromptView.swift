//
//  StitchAIPromptView.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import SwiftUI

struct StitchAIPromptEntryModalView: View {
    @Binding var prompt: String
    let isGenerating: Bool
    let onSubmit: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading) {
            StitchTextView(string: "Enter prompt to generate a project")
            Divider()
            TextEditor(text: $prompt)
                .font(STITCH_FONT)
                .scrollContentBackground(.hidden)
            
            if isGenerating {
                Text("Generating response...")
                    .font(STITCH_FONT)
                    .foregroundColor(.gray)
                    .padding(.top)
            } else {
                Button("Submit") {
                    onSubmit(prompt)
                }
                .disabled(prompt.isEmpty)
                .padding(.top)
            }
        }
        .padding()
    }
}

struct StitchAIState: Equatable {
    var promptState = StitchAIPromptState()
}

struct StitchAIPromptState: Equatable {
    var showModal = false
    var prompt: String = ""
    var isGenerating = false
    var lastPrompt: String? = nil
}

struct StitchAIPromptEdited: StitchDocumentEvent {
    let prompt: String
    
    func handle(state: StitchDocumentViewModel) {
        state.stitchAI.promptState.prompt = prompt
    }
}
