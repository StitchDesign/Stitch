//
//  GraphReducer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/10/24.
//

import Foundation
import StitchSchemaKit

struct MediaCopiedToNewNode: StitchStoreEvent {
    let url: URL
    let location: CGPoint
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.currentGraph?.mediaCopiedToNewNode(newURL: url,
                                                 nodeLocation: location,
                                                 store: store)
        return .noChange
    }
}

struct MediaCopiedToExistingNode: GraphEvent {
    let url: URL
    let nodeMediaImportPayload: NodeMediaImportPayload
    
    func handle(state: GraphState) {
        state.mediaCopiedToExistingNode(nodeImportPayload: nodeMediaImportPayload,
                                        newURL: url)
    }
}

struct ImportFileToNewNode: GraphEventWithResponse {
    let url: URL
    let droppedLocation: CGPoint
    
    func handle(state: GraphState) -> GraphResponse {
        Task { [weak state] in
            await state?.documentEncoderDelegate?
                .importFileToNewNode(fileURL: url,
                                     droppedLocation: droppedLocation)
        }
        
        // won't this run *before* the Task has completed?
        return .shouldPersist
    }
}


struct GraphZoomedIn: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        state.graphZoomedIn()
    }
}

struct GraphZoomedOut: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        state.graphZoomedOut()
    }
}
