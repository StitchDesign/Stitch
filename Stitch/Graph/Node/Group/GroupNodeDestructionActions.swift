//
//  GroupNodeDestructionActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/22/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// DELETING OR UNGROUPING A NODE UI GROUPING

// Group node deletion needs to remove the group node state plus all nodes inside the group
struct GroupNodeDeletedAction: ProjectEnvironmentEvent {
    let groupNodeId: GroupNodeId

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        log("GroupNodeDeletedAction called: groupNodeId: \(groupNodeId)")

        graphState.deleteNode(id: groupNodeId.asNodeId)
        return .persistenceResponse
    }
}

// We uncreated a node-ui-group node via the graph (as opposed to the sidebar).
// We remove the node-ui-grouping but keep
struct GroupNodeUncreated: ProjectEnvironmentEvent {

    let groupId: GroupNodeId // the group that was deleted

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        log("GroupNodeUncreated called for groupId: \(groupId)")
        graphState.handleGroupNodeUncreated(groupId.asNodeId)
        return .noChange
    }
}

extension GraphState {
    // Removes a group node from state, but not its children.
    // Inserts new edges (connections) where necessary,
    // to compensate for the destruction of the GroupNode's input and output splitter nodes.
    @MainActor
    func handleGroupNodeUncreated(_ uncreatedGroupNodeId: NodeId) {
        let newGroupId = self.graphUI.groupNodeFocused?.asNodeId

        // Update nodes to map to new group id
        self.getCanvasItems().forEach { canvasItem in
            if canvasItem.parentGroupNodeId == uncreatedGroupNodeId {
                
                // If this canvas item was a group-splitter-node,
                // completely delete it.
                if let nodeId = canvasItem.nodeDelegate?.id,
                   let node = self.getNode(nodeId), // need the NodeViewModel specifically
                   node.splitterType?.isGroupSplitter ?? false {
                    // Recreate edges if splitter contains upstream and downstream edges
                    self.insertEdgesAfterGroupUncreated(for: node)
                    
                    // Delete splitter input/output nodes here
                    // Can ignore undo effects since that's only for media nodes
                    let _ = self.deleteNode(id: node.id)
                    return
                }
                
                // Else, just assign the ungrouped canvas item to the current traversal level.
                else {
                    canvasItem.parentGroupNodeId = newGroupId
                }
            }
        }

        // Delete group node
        // NOTE: CANNOT USE `GraphState.deleteNode` because that deletes the group node's children as well
        self.visibleNodesViewModel.nodes.removeValue(forKey: uncreatedGroupNodeId)

        // Process and encode changes
        self.updateGraphData()
        self.encodeProjectInBackground()
    }
}

extension GraphState {
    // Recreate edges if splitter contains upstream and downstream edges
    @MainActor
    func insertEdgesAfterGroupUncreated(for splitterNode: NodeViewModel) {
        guard splitterNode.splitterType?.isGroupSplitter ?? false else {
            #if DEBUG
            fatalError()
            #endif
            return
        }

        let splitterOutputCoordinate = NodeIOCoordinate(portId: .zero,
                                                        nodeId: splitterNode.id)

        guard let upstreamOutput = splitterNode.getInputRowObserver(0)?.upstreamOutputCoordinate,
              let downstreamInputsFromSplitter = self.connections.get(splitterOutputCoordinate) else {
            // Nothing to do if no upstream output or downstream inputs
            return
        }

        downstreamInputsFromSplitter.forEach { inputId in
            guard let inputObserver = self.getInputObserver(coordinate: inputId) else {
                return
            }

            // Sets new edges for each connected input
            inputObserver.upstreamOutputCoordinate = upstreamOutput
        }
    }
}
