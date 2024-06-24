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
    
    // Is the
    // can even show a long scrollable json of the encoded actions, so user can double check
    var showPromptModal: Bool = false
    
    var prompt: String = ""
    
    var actions: [LLMAction] = .init()
    var actionsAsDisplayString: String = ""
}
