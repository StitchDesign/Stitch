//
//  NodeInputChnagedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/3/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct InputAddedAction: GraphEventWithResponse {

    let nodeId: NodeId

    func handle(state: GraphState) -> GraphResponse {
        log("InputAddedAction handle called")
        
        guard let node = state.getNode(self.nodeId) else {
            return .noChange
        }

        node.addInputObserver(graph: state)
        
        state.scheduleForNextGraphStep(.init([nodeId]))
        return .persistenceResponse
    }
}

extension NodeViewModel {
    @MainActor
    func addInputObserver(graph: GraphState) {
        guard let inputChanger = self.kind.getPatch?.inputCountChanged else {
            fatalErrorIfDebug()
            return
        }
            
        // (node: node, added?: true)
        inputChanger(self, true)
    }
}

struct InputRemovedAction: GraphEventWithResponse {
    let nodeId: NodeId

    func handle(state: GraphState) -> GraphResponse {
        log("InputRemovedAction handle called")

        if let node = state.getNode(nodeId),
           let inputChanger = node.kind.getPatch?.inputCountChanged,
           // It's always the last input that is removed.
           let lastObserver = node.getAllInputsObservers().last {

            // Remove connections pointing to the input.
            lastObserver.upstreamOutputCoordinate = nil

            // Remove the input from the node itself.
            inputChanger(node, false)
            
            state.scheduleForNextGraphStep(.init([nodeId]))
            
            return .persistenceResponse
        } else {
            log("InputRemovedAction: will not remove input")
            return .noChange
        }
    }
}
