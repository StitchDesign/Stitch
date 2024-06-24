//
//  NodeInputChnagedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/3/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
    @MainActor
    func handleInputAdded(_ nodeId: NodeId) {

        guard let node: NodeViewModel = self.getNodeViewModel(nodeId),
                let lastInputValues = node.inputs.last else {
            log("handleInputAdded: Could not find node or lastInputValues")
            return
        }

        // TODO: OptionSwitch should have special label
        node.appendInputRowObserver(
            NodeRowObserver(
                values: lastInputValues,
                nodeKind: node.kind,
                userVisibleType: node.userVisibleType,
                id: InputCoordinate(portId: node.inputs.count,
                                    nodeId: node.id),
                activeIndex: self.activeIndex,
                upstreamOutputCoordinate: nil,
                nodeIOType: .input,
                nodeDelegate: node))
    }
}

struct InputAddedAction: GraphEventWithResponse {

    let nodeId: NodeId

    func handle(state: GraphState) -> GraphResponse {
        log("InputAddedAction handle called")

        if let node = state.getNodeViewModel(nodeId),
           let inputChanger = node.kind.getPatch?.inputCountChanged {

            // (node: node, added?: true)
            inputChanger(node, true)

            state.calculate(.init([nodeId]))
            
            return .persistenceResponse
        } else {
            log("InputAddedAction: default")
            return .noChange
        }
    }
}

struct InputRemovedAction: GraphEventWithResponse {
    let nodeId: NodeId

    func handle(state: GraphState) -> GraphResponse {
        log("InputRemovedAction handle called")

        if let node = state.getNodeViewModel(nodeId),
           let inputChanger = node.kind.getPatch?.inputCountChanged,
           // It's always the last input that is removed.
           let lastObserver = node.getRowObservers(.input).last {

            // Remove connections pointing to the input.
            lastObserver.upstreamOutputCoordinate = nil

            // Remove the input from the node itself.
            inputChanger(node, false)
            
            state.calculate(.init([nodeId]))
            
            return .persistenceResponse
        } else {
            log("InputRemovedAction: will not remove input")
            return .noChange
        }
    }
}
