//
//  NodeTypeChangedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/8/21.
//

import Foundation
import StitchSchemaKit

// Easier to find than `nodeTypeChanged` which shares same name as several protocol methods.
// Also separates view model update logic from disk-reading/writing side-effects.
struct NodeTypeChanged: GraphEvent {
    let nodeId: NodeId
    let newNodeType: NodeType
    
    @MainActor
    func handle(state: GraphState) {
        let changedIds = state.nodeTypeChanged(nodeId: nodeId,
                                               newNodeType: newNodeType)
        
        // if we successfully changed the node's type, create an LLMAction
        if changedIds.isDefined,
           let node = state.getNodeViewModel(nodeId) {
            state.documentDelegate?.maybeCreateLLMStepChangeValueType(
                node: node,
                newValueType: newNodeType)
        }
        
        state.encodeProjectInBackground()
    }
}

extension GraphState {
    
    /// Helper used by NodeTypeChanged and GroupNodeCreated (coercing type of group splitters)
    @MainActor
    func nodeTypeChanged(nodeId: NodeId,
                         newNodeType: UserVisibleType) -> NodeIdSet? {

        guard let node = self.getNodeViewModel(nodeId) else {
            log("NodeTypeChangedAction: no change...")
            return nil
        }

        guard let oldType = node.userVisibleType else {
            log("NodeTypeChangedAction: node has no node type, so cannot change")
            return nil
        }

        // Change view model
        let changedNodeIds = self.changeType(
            for: node,
            oldType: oldType,
            newType: newNodeType)

        // Recalculate the graph from each of the changed nodes' incoming edges
        let ids = changedNodeIds
            .flatMap { self.immediatelyUpstreamNodes(for: $0) }
            .toSet
            // Always add the node itself, in case node has no incoming edges
            .pureInsert(nodeId)

        self.scheduleForNextGraphStep(ids)
        return ids
    }
    
    @MainActor
    func changeType(for node: NodeViewModel,
                    oldType: UserVisibleType,
                    newType: UserVisibleType) -> NodeIdSet {
        let graphTime = self.graphStepManager.graphTime

        guard let patchNode = node.patchNode else {
            fatalErrorIfDebug()
            return .init()
        }

        // Do nothing if node doesn't support type changes
        guard !patchNode.userTypeChoices.isEmpty else {
            log("GraphState.changeType: type change not supported")
            return Set([node.id])
        }
        
        // TODO: no longer relevant now that classic animation node eval op can create a default animation state when necessary? ... But this may also fix an issue with Spring node?
        node.ephemeralObservers?.forEach {
            $0.nodeTypeChanged(
                oldType: oldType,
                newType: newType,
                kind: node.kind)
        }

        // Convert all values which support type changing
        // Only network node doesn't change inputs
        if patchNode.patch != .networkRequest {
            node.updateNodeTypeAndInputs(
                newType: newType,
                currentGraphTime: graphTime,
                activeIndex: activeIndex,
                graph: self)
        } else {
            // For network request node, we just change the user-visible-type manually.
            patchNode.userVisibleType = newType
        }

        switch patchNode.patch {
            
        case .wirelessBroadcaster:
            let updatedReceivers = self.broadcastNodeTypeChange(
                broadcastNodeId: patchNode.id,
                patchNodes: patchNodes,
                connections: self.connections,
                newNodeType: newType,
                graphTime: graphTime,
                activeIndex: activeIndex)
            return Set([node.id]).union(updatedReceivers)
        default:
            return Set([node.id])
        }
    }
}

