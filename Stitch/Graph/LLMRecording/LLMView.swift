//
//  LLMView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import SwiftUI
import SwiftyJSON

// User has recorded some LLM actions in the app and now assigns a prompt to them
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

struct LLMPromptEdited: GraphUIEvent {
    let prompt: String
    
    func handle(state: GraphUIState) {
        state.llmRecording.promptState.prompt = prompt
    }
}

struct LLMJsonEdited: GraphUIEvent {
    let jsonEntry: String
    
    func handle(state: GraphUIState) {
        state.llmRecording.jsonEntryState.jsonEntry = jsonEntry
    }
}

// User has a json of LLM Actions (created by the
struct LLMActionsJSONEntryModalView: View {
    
    @State var jsonEntry: String = ""
    
    var body: some View {
        VStack(alignment: .leading) {
            StitchTextView(string: "Enter model-generated JSON of LLM Actions")
            Divider()
            TextEditor(text: $jsonEntry)
                .font(STITCH_FONT)
                .scrollContentBackground(.hidden)
        }
        .padding()
        .onChange(of: self.jsonEntry) { oldValue, newValue in
            dispatch(LLMJsonEdited(jsonEntry: jsonEntry))
        }
    }
}



#Preview {
//    LLMPromptModalView()
    LLMActionsJSONEntryModalView()
}
