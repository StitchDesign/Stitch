//
//  GroupNodeCreationActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/22/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
    func getEdgesToUpdate(selectedNodeIds: IdSet,
                          edges: Edges) -> (Edges, Edges) {

        var impliedIds = IdSet()
        for id in selectedNodeIds {
            if let node = self.getNodeViewModel(id),
               node.kind == .group {
                impliedIds = impliedIds.union(
                    self.visibleNodesViewModel
                        .getVisibleNodes(at: id)
                        .map { $0.id }.toSet
                )
            }
        }

        //        log("GroupNodeCreatedEvent: impliedIds: \(impliedIds)")
        //        selectedNodeIds = selectedNodeIds.union(impliedIds)
        //        log("GroupNodeCreatedEvent: selectedNodeIds is now: \(selectedNodeIds)")

        // When creating edges, we must look at all the implied ids as well:
        let allImpliedIds = selectedNodeIds.union(impliedIds)

        // Coordinates outside graph which connect to graph.
        // We'll need to replace these edges later
        var inputEdgesToUpdate: [PortEdgeData] = []
        var outputEdgesToUpdate: [PortEdgeData] = []

        edges.forEach { edge in
            // Determine incoming edges to group to determine group's inputs
            if allImpliedIds.contains(where: { $0 == edge.to.nodeId }),
               !allImpliedIds.contains(where: { $0 == edge.from.nodeId }) {
                inputEdgesToUpdate.append(edge)
            }

            // Determine outgoing edges from group to determine group's outputs
            if allImpliedIds.contains(where: { $0 == edge.from.nodeId }),
               !allImpliedIds.contains(where: { $0 == edge.to.nodeId }) {
                outputEdgesToUpdate.append(edge)
            }
        }

        return (inputEdgesToUpdate, outputEdgesToUpdate)
    }
}

/** Event for creating a group node, which does the following:
 * 1. Determines incoming and outgoing edges to group, whose connections
 *      will need to change to new group node.
 * 2. Creates input and output group nodes.
 * 3. Removes old edges and connections and updates them to new group nodes.
 */
struct GroupNodeCreatedEvent: GraphEventWithResponse {

    @MainActor
    func handle(state: GraphState) -> GraphResponse {

        guard !state.graphUI.llmRecording.isRecording else {
            log("Do not create GroupNodes during LLM Recording")
            return .noChange
        }
        
        let newGroupNodeId = GroupNodeId(id: NodeId())
        let selectedNodeIds = state.selectedNodeIds
        let edges = state.createEdges()

        #if DEV
        // Every selected node must belong to this traversal level.
        let nodesAtThisLevel = state.visibleNodesViewModel.getVisibleNodes().map(\.id).toSet
        if selectedNodeIds.contains { selectedNodeId in !nodesAtThisLevel.contains(selectedNodeId) } {
            fatalError()
        }
        #endif

        let (inputEdgesToUpdate,
             outputEdgesToUpdate) = state.getEdgesToUpdate(
                selectedNodeIds: selectedNodeIds,
                edges: edges)

        // log("GroupNodeCreatedEvent: inputEdgesToUpdate: \(inputEdgesToUpdate)")
        // log("GroupNodeCreatedEvent: outputEdgesToUpdate: \(outputEdgesToUpdate)")

        let center = state.graphUI.center(state.localPosition)
//
        // input splitters need to be west of the `to` node for the `edge`
        
        var oldEdgeToNodeLocations = [NodeIOCoordinate: CGPoint]()
        inputEdgesToUpdate.forEach { edge in
            if let node =  state.getNodeViewModel(edge.to.nodeId) {
                // Move west
                var position = node.position
                position.x -= (200 + node.sizeByLocalBounds.width)
                oldEdgeToNodeLocations[edge.to] = position
            }
        }
        
        inputEdgesToUpdate.forEach { edge in
            
            // Retrieve relevant old-edge's destination node's position
            let to = edge.to
            var nodePosition = oldEdgeToNodeLocations.get(to) ?? center
            
            state.insertIntermediaryNode(
                inBetweenNodesOf: edge,
                newGroupNodeId: newGroupNodeId,
                splitterType: .input,
                position: nodePosition)

            // Increment node position for next input splitter node
            nodePosition.x += NODE_POSITION_STAGGER_SIZE
            nodePosition.y += NODE_POSITION_STAGGER_SIZE
            
            oldEdgeToNodeLocations[to] = nodePosition
        }

        var oldEdgeFromNodeLocations = [NodeIOCoordinate: CGPoint]()
        outputEdgesToUpdate.forEach { edge in
            if let node = state.getNodeViewModel(edge.from.nodeId) {
                // Move east
                var position = node.position
                position.x += (200 + node.sizeByLocalBounds.width)
                oldEdgeFromNodeLocations[edge.from] = position
            }
        }
        
        // output edge = an edge going FROM a node in the group, TO a node outside the group
        outputEdgesToUpdate.forEach { edge in

            // Retrieve relevant old-edge's destination node's position
            let from = edge.from
            var nodePosition = oldEdgeFromNodeLocations.get(from) ?? center
            
            state.insertIntermediaryNode(
                inBetweenNodesOf: edge,
                newGroupNodeId: newGroupNodeId,
                splitterType: .output,
                position: nodePosition)
            
            // Increment node position for next output splitter node
            nodePosition.x += NODE_POSITION_STAGGER_SIZE
            nodePosition.y += NODE_POSITION_STAGGER_SIZE
            
            oldEdgeFromNodeLocations[from] = nodePosition
        }
        
        // Update selected nodes with new parent
        selectedNodeIds.forEach { id in
            state.getNodeViewModel(id)?.parentGroupNodeId = newGroupNodeId.id
        }

        let schema = NodeEntity(id: newGroupNodeId.id,
                                position: center,
                                zIndex: state.highestZIndex + 1,
                                parentGroupNodeId: state.graphUI.groupNodeFocused?.asNodeId,
                                patchNodeEntity: nil,
                                layerNodeEntity: nil,
                                isGroupNode: true,
                                title: NodeKind.group.getDisplayTitle(customName: nil),
                                // Syncs inputs later
                                inputs: [])
        let newGroupNode = NodeViewModel(from: schema,
                                         activeIndex: state.activeIndex,
                                         graphDelegate: state)
        state.visibleNodesViewModel.nodes.updateValue(newGroupNode, forKey: newGroupNode.id)

        // wipe current selectionState and highlighted
        state.graphUI.selection = GraphUISelectionState()
        state.selectedEdges = .init()

        // ... then select the GroupNode and its edges
        state.resetSelectedCanvasItems()
        state.setNodeSelection(newGroupNode, to: true)

        // Stop any active node dragging etc.
        state.graphMovement.stopNodeMovement()

        // Recalculate graph
        state.initializeGraphComputation()
        
        return .persistenceResponse
    }
}

extension GraphMovementObserver {
    func stopNodeMovement() {
        self.draggedNode = nil
        self.lastNodeTranslation = .zero
        self.accumulatedGraphTranslation = .zero
        self.runningGraphTranslationBeforeNodeDragged = nil
    }
}

extension GraphState {
    // Helper method which, given an edge, updates state so that a middle-man
    // node is connected to the `from` and `to` coordinates. Used for
    // inserting input and output group nodes.

    // formerly `insertIntermediaryNode`
    @MainActor
    func insertIntermediaryNode(inBetweenNodesOf oldEdge: PortEdgeData,
                                newGroupNodeId: GroupNodeId,
                                splitterType: SplitterType,
                                position: CGPoint) {

        // log("insertIntermediaryNode: oldEdge: \(oldEdge)")

        guard outputExists(oldEdge.from) else {
            log("insertIntermediaryNode: Couldn't get output while making input group node.")
            return
        }

        // CREATE AND INSERT GROUP SPLITTER NODE

        let newSplitterNodeId = NodeId()

        // TODO: create initializer that can receive `position` and `splitterType`?
        let newSplitterNode = SplitterPatchNode.createViewModel(
            id: newSplitterNodeId,
            position: position,
            zIndex: self.highestZIndex + 1,
            parentGroupNodeId: newGroupNodeId,
            activeIndex: self.activeIndex,
            graphDelegate: self)

        newSplitterNode.position = position
        newSplitterNode.previousPosition = position

        newSplitterNode.splitterType = splitterType

        self.visibleNodesViewModel.nodes.updateValue(newSplitterNode, forKey: newSplitterNode.id)
        
        // Also update newly created group splitter node's type
        if splitterType == .input {
            // New input-splitter node's node type, based on oldEdge's destination
            if let values: PortValues = self.getInputValues(coordinate: oldEdge.to),
               let nodeType = values.first?.toNodeType {
                
                self.nodeTypeChanged(nodeId: newSplitterNodeId,
                                     newNodeType: nodeType)
            }
            
        } else if splitterType == .output {
            if let values: PortValues = self.getInputValues(coordinate: oldEdge.from),
            let nodeType = values.first?.toNodeType {
                self.nodeTypeChanged(nodeId: newSplitterNodeId,
                                     newNodeType: nodeType)
            }
        }

        // UPDATE EDGES

        // Remove the old edge FIRST; otherwise `edgeRemoved` will remove
        self.removeEdgeAt(input: oldEdge.to)

        // Create edge from source patch node to new splitter node
        self.addEdgeWithoutGraphRecalc(
            from: oldEdge.from,
            to: .init(portId: 0, nodeId: newSplitterNodeId))

        // Create edge from new splitter node to downstream node of old connection
        self.addEdgeWithoutGraphRecalc(
            from: .init(portId: 0, nodeId: newSplitterNodeId),
            to: oldEdge.to)
    }

    @MainActor
    func outputExists(_ output: OutputCoordinate) -> Bool {
        self.getPatchNode(id: output.nodeId)?
            .getOutputRowObserver(for: output.portType)
            .isDefined ?? false
    }

}
