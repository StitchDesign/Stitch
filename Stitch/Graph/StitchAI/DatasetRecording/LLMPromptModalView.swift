//
//  LLMPromptModalView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import SwiftUI
import SwiftyJSON

let LLM_OPEN_JSON_ENTRY_MODAL_SF_SYMBOL = "rectangle.and.pencil.and.ellipsis"

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

struct LLMJsonEdited: StitchDocumentEvent {
    let jsonEntry: String
    
    func handle(state: StitchDocumentViewModel) {
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


extension StitchDocumentViewModel {
    @MainActor func openedLLMActionsJSONEntryModal() {
        self.llmRecording.jsonEntryState.showModal = true
        self.graphUI.reduxFocusedField = .llmRecordingModal
    }

    // When json-entry modal is closed, we turn the JSON of LLMActions into state changes
    @MainActor func closedLLMActionsJSONEntryModal() {
        let jsonEntry = self.llmRecording.jsonEntryState.jsonEntry
        
        self.llmRecording.jsonEntryState.showModal = false
        self.llmRecording.jsonEntryState.jsonEntry = ""
        self.graphUI.reduxFocusedField = nil
        
        guard !jsonEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log("LLMActionsJSONEntryModalClosed: json entry")
            return
        }
        
        do {
            let json = JSON(parseJSON: jsonEntry) // returns null json if parsing fails
            let data = try json.rawData()
            let actions: LLMStepActions = try JSONDecoder().decode(LLMStepActions.self,
                                                               from: data)
            
            var canvasItemsAdded = 0
            actions.forEach {
                canvasItemsAdded = self.handleLLMStepAction(
                    $0,
                    canvasItemsAdded: canvasItemsAdded)
            }
            self.llmRecording.jsonEntryState = .init() // reset
            self.visibleGraph.encodeProjectInBackground()
        } catch {
            log("LLMActionsJSONEntryModalClosed: Error: \(error)")
            fatalErrorIfDebug("LLMActionsJSONEntryModalClosed: could not decode LLMStepActions")
        }
    }
}


#Preview {
//    LLMPromptModalView()
    LLMActionsJSONEntryModalView()
}
