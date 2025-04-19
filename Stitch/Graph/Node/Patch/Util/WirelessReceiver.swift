//
//  Wireless.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/22/21.
//

import Foundation
import StitchSchemaKit

// When a broadcaster is assigned to a receiver:
// -- create a connection and an invisible edge from broadcaster output to receiver input
struct SetBroadcastForWirelessReceiver: StitchDocumentEvent {
    let broadcasterNodeId: NodeId?
    let receiverNodeId: NodeId

    func handle(state: StitchDocumentViewModel) {

        log("SetBroadcastForWirelessReceiver called")
        log("SetBroadcastForWirelessReceiver: broadcasterNodeId: \(broadcasterNodeId?.uuidString ?? "none")")
        log("SetBroadcastForWirelessReceiver: receiverNodeId: \(receiverNodeId)")
        
        let graph = state.visibleGraph
        let graphTime = state.graphStepManager.graphTime

        guard let receiverNode = graph.getPatchNode(id: receiverNodeId),
              let receiverNodeInputObserver = receiverNode.getInputRowObserver(0) else {
            log("SetBroadcastForWirelessReceiver: could not find received node \(receiverNodeId)")
            return
        }

        // If we DE-ASSIGNED a broadcaster from this receiver,
        // then we simply remove receiver's incoming edges.
        guard let broadcasterNodeId = broadcasterNodeId else {
            log("SetBroadcastForWirelessReceiver: did not have broadcasterNodeId")

            // Note 1: we may not have actually had an edge, e.g. if we were already on a nil broadcaster.
            // Note 2: removeAnyEdges already recalculates the graph from the `to` node of the removed edge.

            receiverNodeInputObserver.removeUpstreamConnection(node: receiverNode)
            
            graph.scheduleForNextGraphStep(receiverNodeId)
            
            state.encodeProjectInBackground()
            return
        }

        // Find the broadcaster and the receiver.
        guard let broadcasterNode = graph.getPatchNode(id: broadcasterNodeId) else {
            log("SetBroadcastForWirelessReceiver: could not find node for broadcaster id \(broadcasterNodeId)")
            return
        }

        // wireless nodes only have a single input and output
        let broadcasterOutput = OutputCoordinate(portId: 0, nodeId: broadcasterNodeId)

        graph.edgeAdded(edge: .init(from: broadcasterOutput,
                                         to: receiverNodeInputObserver.id))

        // Need to also change type of the wireless receiver node to be same as broadcaster's:
        receiverNode.updateNodeTypeAndInputs(
            newType: broadcasterNode.userVisibleType!,
            currentGraphTime: graphTime,
            activeIndex: state.activeIndex,
            graph: graph)

        // Then recalculate the graph from the broadcaster onward:
        graph.scheduleForNextGraphStep(broadcasterNodeId)

        state.encodeProjectInBackground()
    }
}
