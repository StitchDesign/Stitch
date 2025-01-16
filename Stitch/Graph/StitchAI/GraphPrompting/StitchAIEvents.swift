//
//  StitchAIEvents.swift
//  Stitch
//
//  Created by Nicholas Arner on 10/10/24.
//

import Foundation
import SwiftUI
import SwiftyJSON

extension StitchDocumentViewModel {
    
    @MainActor
    func openedStitchAIModal() {
        self.stitchAI.promptState.showModal = true
        self.graphUI.reduxFocusedField = .stitchAIPromptModal
    }
    
    // When json-entry modal is closed, we turn the JSON of LLMActions into state changes
    @MainActor
    func closedStitchAIModal() {
        let prompt = self.stitchAI.promptState.prompt
        
        self.stitchAI.promptState.showModal = false
        self.graphUI.reduxFocusedField = nil
        
        // HACK until we figure out why this is called twice
        if prompt == "" {
            return
        }
        
        // Only submit API request via 'submit'
        // dispatch(MakeOpenAIRequest(prompt: prompt))
        
        self.stitchAI.promptState.prompt = ""
    }
    
    @MainActor
    func closeStitchAIModal() {
        self.stitchAI.promptState.showModal = false
        self.stitchAI.promptState.prompt = ""
        self.graphUI.reduxFocusedField = nil
    }
    
    func showErrorModal(message: String, userPrompt: String, jsonResponse: String?) {
        DispatchQueue.main.async {
            if let rootViewController = UIApplication.shared.windows.first?.rootViewController {
                let hostingController = UIHostingController(rootView: StitchAIErrorModalView(
                    message: message,
                    userPrompt: userPrompt,
                    jsonResponse: jsonResponse
                ))
                rootViewController.present(hostingController, animated: true, completion: nil)
            }
        }
    }
}

struct StitchAIPromptSubmitted: StitchDocumentEvent {
    @MainActor func handle(state: StitchDocumentViewModel) {
        let prompt = state.stitchAI.promptState.prompt
        // Store the prompt as the lastPrompt before making the request
        state.stitchAI.promptState.lastPrompt = prompt
        state.stitchAI.promptState.showModal = false
        
        dispatch(MakeOpenAIRequest(prompt: prompt))
    }
}
