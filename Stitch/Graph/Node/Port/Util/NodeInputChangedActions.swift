//
//  NodeInputChnagedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/3/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct InputAddedAction: StitchDocumentEvent {

    let nodeId: NodeId

    func handle(state: StitchDocumentViewModel) {
        log("InputAddedAction handle called")
        let graph = state.visibleGraph
        
        guard let node = graph.getNode(self.nodeId) else {
            return
        }

        node.addInputObserver(graph: graph,
                              document: state)
        
        graph.scheduleForNextGraphStep(.init([nodeId]))
        state.encodeProjectInBackground()
    }
}

//extension NodeViewModel {
//    @MainActor
//    func addInputObserver(graph: GraphState) {
//        self.inputadd
//
//        guard let inputChanger = self.kind.getPatch?.inputCountChanged else {
//            fatalErrorIfDebug()
//            return
//        }
//            
//        // (node: node, added?: true)
//        inputChanger(self, true)
//    }
//}

struct InputRemovedAction: GraphEventWithResponse {
    let nodeId: NodeId

    func handle(state: GraphState) -> GraphResponse {
        log("InputRemovedAction handle called")

        if let node = state.getNode(nodeId),
           // It's always the last input that is removed.
           let lastObserver = node.getAllInputsObservers().last {

            // Remove connections pointing to the input.
            lastObserver.upstreamOutputCoordinate = nil

            // Remove the input from the node itself.
            node.removeInputObserver()
            
            state.scheduleForNextGraphStep(.init([nodeId]))
            
            return .persistenceResponse
        } else {
            log("InputRemovedAction: will not remove input")
            return .noChange
        }
    }
}
