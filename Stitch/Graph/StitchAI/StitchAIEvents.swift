//
//  StitchAIEvents.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation

extension StitchDocumentViewModel {
    @MainActor func openedStitchAIModal() {
        self.stitchAI.promptEntryState.showModal = true
        self.graphUI.reduxFocusedField = .stitchAIPromptModal
    }

    // When json-entry modal is closed, we turn the JSON of LLMActions into state changes
    @MainActor func closedStitchAIModal() {
        let jsonEntry = self.llmRecording.jsonEntryState.jsonEntry
        
        self.stitchAI.promptEntryState.showModal = false
        self.stitchAI.promptEntryState.prompt = ""
        self.graphUI.reduxFocusedField = nil
        
        guard !jsonEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            log("LLMActionsJSONEntryModalClosed: prompt entry")
            return
        }
        
//        do {
//            let json = JSON(parseJSON: jsonEntry) // returns null json if parsing fails
//            let data = try json.rawData()
//            let actions: LLMActions = try JSONDecoder().decode(LLMActions.self,
//                                                               from: data)
//            actions.forEach { self.handleLLMAction($0) }
//            self.llmRecording.jsonEntryState = .init() // reset
//            self.visibleGraph.encodeProjectInBackground()
//        } catch {
//            log("LLMActionsJSONEntryModalClosed: Error: \(error)")
//            fatalErrorIfDebug("LLMActionsJSONEntryModalClosed: could not retrieve")
//        }
    }

}
