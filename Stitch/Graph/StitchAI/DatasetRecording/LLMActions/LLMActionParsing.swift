//
//  LLMEvents.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import SwiftyJSON
import StitchSchemaKit



let STITCH_AI_SF_SYMBOL = "lasso.badge.sparkles"

// MARK: turning a JSON of LLM Actions into state changes in the app

let LLM_OPEN_JSON_ENTRY_MODAL_SF_SYMBOL = "rectangle.and.pencil.and.ellipsis"

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
