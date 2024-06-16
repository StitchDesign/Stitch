//
//  Wireless.swift
//  prototype
//
//  Created by Christian J Clampitt on 11/22/21.
//

import Foundation
import StitchSchemaKit

// When a broadcaster is assigned to a receiver:
// -- create a connection and an invisible edge from broadcaster output to receiver input
struct SetBroadcastForWirelessReceiver: ProjectEnvironmentEvent {
    let broadcasterNodeId: NodeId?
    let receiverNodeId: NodeId

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {

        log("SetBroadcastForWirelessReceiver called")
        log("SetBroadcastForWirelessReceiver: broadcasterNodeId: \(broadcasterNodeId?.uuidString ?? "none")")
        log("SetBroadcastForWirelessReceiver: receiverNodeId: \(receiverNodeId)")

        let graphTime = graphState.graphStepManager.graphTime

        guard let receiverNode = graphState.getPatchNode(id: receiverNodeId),
              let receiverNodeInputObserver = receiverNode.getInputRowObserver(0) else {
            log("SetBroadcastForWirelessReceiver: could not find received node \(receiverNodeId)")
            return .noChange
        }

        // If we DE-ASSIGNED a broadcaster from this receiver,
        // then we simply remove receiver's incoming edges.
        guard let broadcasterNodeId = broadcasterNodeId else {
            log("SetBroadcastForWirelessReceiver: did not have broadcasterNodeId")

            // Note 1: we may not have actually had an edge, e.g. if we were already on a nil broadcaster.
            // Note 2: removeAnyEdges already recalculates the graph from the `to` node of the removed edge.

            receiverNodeInputObserver.removeUpstreamConnection(activeIndex: graphState.activeIndex,
                                                               isVisible: receiverNode.isVisibleInFrame)
            graphState.calculate(receiverNodeId)
            
            return .init(willPersist: true)
        }

        // Find the broadcaster and the receiver.
        guard let broadcasterNode = graphState.getPatchNode(id: broadcasterNodeId) else {
            log("SetBroadcastForWirelessReceiver: could not find node for broadcaster id \(broadcasterNodeId)")
            return .noChange
        }

        // wireless nodes only have a single input and output
        let broadcasterOutput = OutputCoordinate(portId: 0, nodeId: broadcasterNodeId)

        graphState.edgeAdded(edge: .init(from: broadcasterOutput,
                                         to: receiverNodeInputObserver.id))

        // Need to also change type of the wireless receiver node to be same as broadcaster's:
        receiverNode.updateNodeTypeAndInputs(
            newType: broadcasterNode.userVisibleType!,
            currentGraphTime: graphTime,
            activeIndex: graphState.activeIndex)

        // Then recalculate the graph from the broadcaster onward:
        graphState.calculate(broadcasterNodeId)

        return .persistenceResponse
    }
}
