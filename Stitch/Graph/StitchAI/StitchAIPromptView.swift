//
//  StitchAIPromptView.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import SwiftUI

struct StitchAIPromptEntryModalView: View {
    
    @State var prompt: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            StitchTextView(string: "Enter prompt to generate a project")
            Divider()
            TextEditor(text: $prompt)
                .font(STITCH_FONT)
                .scrollContentBackground(.hidden)
        }
        .padding()
        .onChange(of: self.prompt) { oldValue, newValue in
            dispatch(LLMJsonEdited(jsonEntry: prompt))
        }
    }
}

struct PromptEdited: StitchDocumentEvent {
    let prompt: String
    
    func handle(state: StitchDocumentViewModel) {
        state.stitchAI.promptEntryState.prompt = prompt
    }
}
