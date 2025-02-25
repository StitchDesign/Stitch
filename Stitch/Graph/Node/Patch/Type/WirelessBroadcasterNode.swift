//
//  WirelessBroadcasterNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/22/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func wirelessBroadcasterNode(id: NodeId,
                             n: Double = 0,
                             position: CGSize = .zero,
                             zIndex: Double = 0.0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: (nil, [.number(n)]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [.number(n)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .wirelessBroadcaster,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

extension GraphState {
    /// Returns id set of changed nodes.
    @MainActor
    func broadcastNodeTypeChange(broadcastNodeId: NodeId,
                                 patchNodes: NodesViewModelDict,
                                 connections: Connections,
                                 newNodeType: UserVisibleType,
                                 graphTime: TimeInterval,
                                 activeIndex: ActiveIndex) -> NodeIdSet {
        // If this broadcast node has connections,
        // those connections must be receivers whose types we also need to change.
        // (Assumes wireless-broadcasters can only have connections to wireless-receivers.)
        guard let receivingInputs = connections
            .get(.init(portId: 0, nodeId: broadcastNodeId)) else {
            return .init()
        }

        var updateReceiversResults = NodeIdSet()

        receivingInputs.forEach {
            if let node = patchNodes.get($0.nodeId) {
                // we want to update the node type and inputs types
                node.updateNodeTypeAndInputs(newType: newNodeType,
                                             currentGraphTime: graphTime,
                                             activeIndex: activeIndex,
                                             graph: self)
                
                /*
                 When a Wireless Broadcaster's node-type changes, we updates its inputs (and thus outputs, since Wireless node's evals are just `identity`),
                 as well as the node-type (and inputs) of any assigned Wireless Receivers.
                 
                 In both cases we coerce the existing inputs' values to some simple default for the new node-type; e.g. "love" becomes 1, "" becomes 0 if we're changing from String node-type to Number node-type.
                 
                 Since we've already changed the Wireless Receiver's input, we can't rely on the "old input vs new input" change in `updateDownstreamInputs`.
                 */
                self.scheduleForNextGraphStep(node.id)
                updateReceiversResults.insert(node.id)
            }
        }

        return updateReceiversResults
    }
}
