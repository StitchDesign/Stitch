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
    case normal
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
    case enterPromptForTrainingData
    
    // Modal (toast) from which user can rate the just-completed streaming request
    case ratingToast(OpenAIRequest)
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
    
    var currentlyInARetryDelay: Bool = false
    
    // TODO: should this live on StitchAIManager's `currentTask` ?
    // Tracks steps as they come in
    var streamedSteps: OrderedSet<Step> = .init()
    
    // Are we actively recording redux-actions which we then turn into LLM-actions?
    var isRecording: Bool = false
    
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
    
    // User has been recording a fresh training case; they provide this natural language description of what the training case is about / supposed to be.
    var promptForJustCompletedTrainingData: String = ""
}
