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


let LLM_COLLECTION_DIRECTORY = "StitchDataCollection"

enum LLMRecordingMode: Equatable {
    case normal // What does 'normal' really mean?
    case augmentation
}

enum LLMRecordingModal: Equatable, Hashable {
    // No active modal
    case none
    
    // Modal from which user can edit LLM Actions (remove those created by model or user; add new ones by interacting with the graph)
    case editBeforeSubmit
    
    // Modal from which user either (1) re-enters LLM edit mode or (2) finally approves the LLM action list and send to Supabase
    case approveAndSubmit
    
    // Modal from which user can enter a natural language prompt for the fresh training example they have *just finished creating*
    // TODO: phase this out? Just submit whole graph / selected patches and layers as a training example
    case enterPromptForTrainingData
    
    // Modal (toast) from which user can rate the just-completed streaming request
    case ratingToast(userInputPrompt: String) // OpenAIRequest.prompt i.e. user's natural language input
    
    // Modal from which user provides prompt and rating for an existing graph, which is then uploaded to Supabase as an example
    case submitExistingGraphAsTrainingExample
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
    
    // Are we actively turning graph changes into AI-actions?
    var isRecording: Bool = false
    
    // TODO: what does
    // Track whether we've shown the modal in normal mode
    var hasShownModalInNormalMode: Bool = false
    
    // Do not create LLMActions while we are applying LLMActions
    var isApplyingActions: Bool = false
    
    // Error from validating or applying the LLM actions;
    // Note: we can actually have several, but only display one at a time
    var actionsError: String?
        
    // Normal vs. Augmentation ('correction')
    var mode: LLMRecordingMode = .normal
    
    // TODO: rename to `steps`, to distinguish between `Step` vs `StepActionable` ?
    var actions: [any StepActionable] = .init()
            
    // No modal vs Edit actions list vs Approve and submit vs Enter prompt for just-created training data
    var modal: LLMRecordingModal = .none
    
    // Tracks node positions, persisting across edits in case node is removed from validation failure
    var canvasItemPositions: [CanvasItemId : CGPoint] = .init()
    
    // Runs validation after every change
    var willAutoValidate = true
    
    // Tracks graph state before recording
    var initialGraphState: GraphEntity?
    
    // The prompt we've manually provided for our training example;
    // OR the saved prompt from a streaming request that has been completed
    var promptForTrainingDataOrCompletedRequest: String?
    var promptFromPreviousExistingGraphSubmittedAsTrainingData: String?
    
    // id from a user inference call; used
    var requestIdFromCompletedRequest: UUID?
    
    var rating: StitchAIRating?
    var ratingFromPreviousExistingGraphSubmittedAsTrainingData: StitchAIRating?
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
