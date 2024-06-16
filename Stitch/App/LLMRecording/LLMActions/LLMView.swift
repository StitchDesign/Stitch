//
//  LLMView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import SwiftUI
import SwiftyJSON

struct LLMPromptModalView: View {
        
    let actionsAsDisplay: String
        
    @State var prompt: String = ""
    
    var body: some View {
        VStack {
            HStack {
                Text("Prompt: ")
                    .font(STITCH_FONT)
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
        state.llmRecording.prompt = prompt
    }
}

//#Preview {
//    LLMPromptModalView()
//}
