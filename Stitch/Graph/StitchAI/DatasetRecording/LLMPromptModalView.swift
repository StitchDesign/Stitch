//
//  LLMPromptModalView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import SwiftUI
import SwiftyJSON

// User has recorded some LLM Steps in the app and now assigns a prompt to them
struct LLMPromptModalView: View {
        
    let actionsAsDisplay: String
        
    @State var prompt: String = ""
    
    var body: some View {
        VStack {
            HStack {
                StitchTextView(string: "Prompt: ")
                TextField("", text: $prompt)
                    .font(STITCH_FONT)
            }
            Divider()
            TextEditor(text: .constant(actionsAsDisplay))
                .font(STITCH_FONT)
                .scrollContentBackground(.hidden)
        }
        .padding()
        .onChange(of: self.prompt) { oldValue, newValue in
            dispatch(LLMPromptEdited(prompt: newValue))
        }
    }
}

struct LLMPromptEdited: StitchDocumentEvent {
    let prompt: String
    
    func handle(state: StitchDocumentViewModel) {
        state.llmRecording.promptState.prompt = prompt
    }
}
