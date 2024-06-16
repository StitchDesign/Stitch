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

struct MediaCopiedToExistingNode: StitchStoreEvent {
    let url: URL
    let nodeMediaImportPayload: NodeMediaImportPayload
    
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        store.currentGraph?.mediaCopiedToExistingNode(nodeImportPayload: nodeMediaImportPayload,
                                                      newURL: url,
                                                      store: store)
        return .noChange
    }
}

struct ImportFileToNewNode: GraphEventWithResponse {
    let url: URL
    let droppedLocation: CGPoint
    
    func handle(state: GraphState) -> GraphResponse {
        Task { [weak state] in
            await state?.importFileToNewNode(fileURL: url,
                                             droppedLocation: droppedLocation)
        }
        
        // won't this run *before* the Task has completed?
        return .shouldPersist
    }
}


struct GraphZoomedIn: GraphEvent {
    func handle(state: GraphState) {
        state.graphZoomedIn()
    }
}

struct GraphZoomedOut: GraphEvent {
    func handle(state: GraphState) {
        state.graphZoomedOut()
    }
}
