//
//  LLMRecordingState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine
import OrderedCollections


struct ShowAINodePromptEntryModal: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        state.llmRecording.modal = .aiNodePromptEntry
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func aiNodePromptSubmitted() {
        
        let document = self
        
        // On submit, create a javascript node
        let aiNode = document.nodeInserted(choice: .patch(.javascript))
        guard let aiPatchNode = aiNode.patchNode else {
            fatalErrorIfDebug()
            return
        }
        
        aiPatchNode.canvasObserver.isLoading = true
        
        document.graph.updateGraphData(document)
        
        
        do {
            let jsAIRequest = try AIEditJSNodeRequest(
                prompt: document.llmRecording.aiNodePrompt,
                document: document,
                nodeId: aiNode.id)
            
            Task { [weak aiNode, weak aiPatchNode, weak document] in
                guard let aiPatchNode = aiPatchNode,
                      let document = document,
                      let aiManager = document.aiManager else {
                    return
                }
                
                // TODO: move to a `willRequest` for the Javascript Request ?
                willRequest_SideEffect(
                    userPrompt: jsAIRequest.userPrompt,
                    requestId: jsAIRequest.id,
                    document: document,
                    canShareData: StitchStore.canShareAIData,
                    userPromptTableName: nil)
                                    
                let result = await jsAIRequest.request(document: document,
                                                       aiManager: aiManager)
                
                switch result {
                
                case .success(let jsSettings):
                    log("success: jsSettings: \(jsSettings)")
                    
                    try await aiManager.uploadJavascriptCallResultToSupabase(
                        userPrompt: jsAIRequest.userPrompt,
                        requestId: jsAIRequest.id,
                        javascriptSettings: jsSettings)
                    
                    aiPatchNode.canvasObserver.isLoading = false
                    
                    // Process the new Javascript settings
//                    aiPatchNode.processNewJavascript(response: jsSettings,
//                                                     document: document)
                    aiPatchNode.processNewJavascript(response: jsSettings)
                    
                    document.graph.updateGraphData(document)
                    
                case .failure(let error):
                    log("failure: error: \(error)")
                    fatalErrorIfDebug(error.description)
                }
            }
        } catch {
            log("javascriptNodeField error: \(error.localizedDescription)")
        }
    }
}

let LLM_COLLECTION_DIRECTORY = "StitchDataCollection"

enum LLMRecordingModal: Equatable, Hashable {
    // No active modal
    case none
    
    // Modal from which user can edit LLM Actions (remove those created by model or user; add new ones by interacting with the graph)
    case editBeforeSubmit
    
    // Modal (toast) from which user can rate the just-completed streaming request
    case ratingToast(userInputPrompt: String) // OpenAIRequest.prompt i.e. user's natural language input
    
    // Modal from which user provides prompt and rating for an existing graph, which is then uploaded to Supabase as an example
    case submitExistingGraphAsTrainingExample
    
    // Modal from which user provides prompt for an AI Node
    case aiNodePromptEntry
}

extension LLMRecordingModal {
    var isRatingToast: Bool {
        switch self {
        case .ratingToast:
            return true
        default:
            return false
        }
    }
}

struct LLMRecordingState {
    
    // If we're currently in a retry delay, we don't want to
    var currentlyInARetryDelay: Bool = false
    
    // TODO: should this live on StitchAIManager's `currentTask` ?
    // Tracks steps as they stream in
    var streamedSteps: OrderedSet<Step> = .init()

    // Do not create LLMActions while we are applying LLMActions
    var isApplyingActions: Bool = false
    
    // Error from validating or applying the LLM actions;
    // Note: we can actually have several, but only display one at a time
    var actionsError: String?
    
    // TODO: rename to `steps`, to distinguish between `Step` vs `StepActionable` ?
    var actions: [any StepActionable] = .init()
            
    // No modal vs Edit actions list vs Approve and submit vs Enter prompt for just-created training data
    var modal: LLMRecordingModal = .none
    
    // TODO: probably better to make an enum case in the `modal`
    var willDisplayTrainingPrompt = false
    
    var aiNodePrompt: String = ""
    
    var showAINodePromptEntry: Bool {
        get {
            self.modal == .aiNodePromptEntry
        } set {
            if newValue {
                self.modal = .aiNodePromptEntry
            } else {
                if self.modal == .aiNodePromptEntry {
                    self.modal = .none
                }
            }
        }
    }
    
    // Tracks node positions, persisting across edits in case node is removed from validation failure
    var canvasItemPositions: [CanvasItemId : CGPoint] = .init()
    
    // Runs validation after every change
    var willAutoValidate = true
    
    // Tracks graph state before recording
    var initialGraphState: GraphEntity?
    
    // The prompt we've manually provided for our training example;
    // OR the saved prompt from a streaming request that has been completed
    var promptForTrainingDataOrCompletedRequest: String = ""
    var promptFromPreviousExistingGraphSubmittedAsTrainingData: String?
    
    
    
    // id from a user inference call; used
    var requestIdFromCompletedRequest: UUID?
    
    var rating: StitchAIRating?
    var ratingFromPreviousExistingGraphSubmittedAsTrainingData: StitchAIRating?
}

extension LLMRecordingState {
    var isAugmentingAIActions: Bool {
        self.modal == .editBeforeSubmit
    }
}


// TODO: can we organize AI-related logic/state by use-case ? e.g. generating nodes/layers vs a javascript node, vs creating a training example
// "correcting actions" would fall under "generating graph"
// There's a lot of state and views that overlap across use-cases...

enum StitchAIMode: Equatable, Hashable {
    
    // Our classic use case: user submits prompt via node menu, which adds layers and patches to the current document
    case generatingGraph
    
    // Our new use case: user submits prompt for a Javascript node, which adds a single JS node to the canvas
    case generatingJavascriptNode
    
    // e.g. turning an existing graph into
    case creatingTrainingData
}
