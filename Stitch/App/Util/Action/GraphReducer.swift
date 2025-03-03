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
        store.currentDocument?.visibleGraph.mediaCopiedToNewNode(newURL: url,
                                                                 nodeLocation: location,
                                                                 store: store)
        return .noChange
    }
}

struct MediaCopiedToExistingNode: StitchDocumentEvent {
    let url: URL
    let nodeMediaImportPayload: NodeMediaImportPayload
    
    func handle(state: StitchDocumentViewModel) {
        state.visibleGraph.mediaCopiedToExistingNode(nodeImportPayload: nodeMediaImportPayload,
                                                     newURL: url,
                                                     activeIndex: state.activeIndex)
    }
}

struct ImportFileToNewNode: GraphEventWithResponse {
    let url: URL
    let droppedLocation: CGPoint
    
    func handle(state: GraphState) -> GraphResponse {
        let center = state.documentDelegate?.viewPortCenter ?? .zero
        Task { [weak state] in
            await state?.documentEncoderDelegate?
                .importFileToNewNode(fileURL: url,
                                     // TODO: use real drop location
                                     droppedLocation: center)
        }
        
        // won't this run *before* the Task has completed?
        return .shouldPersist
    }
}

struct GraphZoomedIn: GraphEvent {
    func handle(state: GraphState) {
        state.graphZoomedIn(.shortcutKey)
    }
}

struct GraphZoomedOut: GraphEvent {
    func handle(state: GraphState) {
        state.graphZoomedOut(.shortcutKey)
    }
}
