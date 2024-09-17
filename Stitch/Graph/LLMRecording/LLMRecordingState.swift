//
//  LLMRecordingState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/24.
//

import Foundation

let LLM_COLLECTION_DIRECTORY = "StitchDataCollection"

struct LLMRecordingState: Equatable {
    
    // Are we actively recording redux-actions which we then turn into LLM-actions?
    var isRecording: Bool = false
    
    var actions: [LLMAction] = .init()

    var promptState = LLMPromptState()
    
    var jsonEntryState = LLMJsonEntryState()
}

struct LLMPromptState: Equatable {
    // can even show a long scrollable json of the encoded actions, so user can double check
    var showModal: Bool = false
    
    var prompt: String = ""
        
    // cached; updated when we open the prompt modal
    // TODO: find a better way to write the view such that the json's (of the encoded actions) keys are not shifting around as user types
    var actionsAsDisplayString: String = ""
}

struct LLMJsonEntryState: Equatable {
    var showModal = false
    
    var jsonEntry: String = ""
    
    // Mapping of LLM node ids (e.g. "123456") to the id created
    var llmNodeIdMapping = LLMNodeIdMapping()
}

typealias LLMNodeIdMapping = [String: NodeId]

extension StitchDocumentViewModel {
    var llmNodeIdMapping: LLMNodeIdMapping {
        get {
            self.llmRecording.jsonEntryState.llmNodeIdMapping
        } set(newValue) {
            self.llmRecording.jsonEntryState.llmNodeIdMapping = newValue
        }
    }
}
