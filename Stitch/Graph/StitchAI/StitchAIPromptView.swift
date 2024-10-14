//
//  StitchAIPromptView.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import SwiftUI

struct StitchAIPromptEntryModalView: View {
    @AppStorage(OPENAI_API_KEY_NAME) var OPEN_AI_API_KEY: String = ""

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
            dispatch(StitchAIPromptEdited(prompt: newValue))
        }
    }
}

struct StitchAIState: Equatable {
    var promptState = StitchAIPromptState()
}

struct StitchAIPromptState: Equatable {
    var showModal = false
    var prompt: String = ""
}

struct StitchAIPromptEdited: StitchDocumentEvent {
    let prompt: String
    
    func handle(state: StitchDocumentViewModel) {
        state.stitchAI.promptState.prompt = prompt
    }
}
