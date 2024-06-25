//
//  GroupNodeCreationActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/22/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias CanvasItemIdSet = Set<CanvasItemId>

extension GraphState {
    
    @MainActor
    func canvasItemsImpliedBySelectedGroupNodes(_ selectedCanvasItems: CanvasItemIdSet) -> CanvasItemIdSet {
        var impliedIds = CanvasItemIdSet()
    
        let selectedGroupNodes = selectedCanvasItems.compactMap { canvasItem in
            if let nodeId = canvasItem.nodeCase, self.getNode(nodeId)?.isGroupNode ?? false {
                return nodeId
            }
            return nil
        }
        
        for id in selectedGroupNodes {
            
            let visibleCanvasItemsForSelectedGroupNode = self.visibleNodesViewModel
                .getVisibleCanvasItems(at: id)
                .reduce(into: CanvasItemIdSet(), { $0.insert($1.id) })
            
            impliedIds = impliedIds.union(visibleCanvasItemsForSelectedGroupNode)
        }
        
        return impliedIds
    }
    
    // Edges that will (may?) change in the process of creating a group-ui-node
    @MainActor
    func getEdgesToUpdate(selectedCanvasItems: CanvasItemIdSet,
                          edges: Edges) -> (Edges, Edges) {

        let impliedIds = canvasItemsImpliedBySelectedGroupNodes(selectedCanvasItems)

        //        log("GroupNodeCreatedEvent: impliedIds: \(impliedIds)")
        //        selectedNodeIds = selectedNodeIds.union(impliedIds)
        //        log("GroupNodeCreatedEvent: selectedNodeIds is now: \(selectedNodeIds)")

        // When creating edges, we must look at all the implied ids as well:
        let allImpliedIds = selectedCanvasItems.union(impliedIds)

        // Coordinates outside graph which connect to graph.
        // We'll need to replace these edges later
        var inputEdgesToUpdate: [PortEdgeData] = []
        var outputEdgesToUpdate: [PortEdgeData] = []

        edges.forEach { edge in
            // why were we testing against node id, rather than input or output coordinate?
            
            let destinationIsInsideGroup = allImpliedIds.contains(edge.to.inputCoordinateAsCanvasItemId)
            
            // You're asking: does this edge originate from an output that will be put into the group?
            // What you have is a set of canvas items.
            // You could just compare against node ids? ... But that won't work for layer inputs/outputs, since one layer input could sit inside the graph while the other sits outside.
            
            // Suppose we have selected the following canvas items: 1 patch node, 1 layer input, 1 layer output
            
            // To know whether an output is from a patch node or a layer node, you would have to check the node itself.
            
            let originIsInsideGroup = allImpliedIds.contains(edge.from.outputCoordinateAsCanvasItemId(self))
            
            // Will the destination be put in the group, but the origin stays outside? if so, that is an "input edge to update" i.e. an edge coming into the group
            if destinationIsInsideGroup && !originIsInsideGroup {
                inputEdgesToUpdate.append(edge)
            } 
            
            // Will the origin be put in the group, but the destination stays outside? if so, that is an "output edge to update" i.e. an edge coming out of the group
            else if originIsInsideGroup && !destinationIsInsideGroup {
                outputEdgesToUpdate.append(edge)
            }
        }

        return (inputEdgesToUpdate, outputEdgesToUpdate)
    }
    
    func getInitialOldEdgeToNodeLocations(inputEdgesToUpdate: Edges) -> [NodeIOCoordinate: CGPoint] {
        var oldEdgeToNodeLocations = [NodeIOCoordinate: CGPoint]()
        inputEdgesToUpdate.forEach { edge in
            if let node =  self.getNodeViewModel(edge.to.nodeId) {
                // Move west
                var position = node.position
                position.x -= (200 + node.sizeByLocalBounds.width)
                oldEdgeToNodeLocations[edge.to] = position
            }
        }
        return oldEdgeToNodeLocations
    }
    
    func getInitialOldEdgeFromNodeLocations(outputEdgesToUpdate: Edges) -> [NodeIOCoordinate: CGPoint] {
        var oldEdgeFromNodeLocations = [NodeIOCoordinate: CGPoint]()
        outputEdgesToUpdate.forEach { edge in
            if let node = self.getNodeViewModel(edge.from.nodeId) {
                // Move east
                var position = node.position
                position.x += (200 + node.sizeByLocalBounds.width)
                oldEdgeFromNodeLocations[edge.from] = position
            }
        }
        return oldEdgeFromNodeLocations
    }
    
    @MainActor
    func createGroupNode(newGroupNodeId: GroupNodeId,
                         center: CGPoint) -> NodeViewModel {
        
        let schema = NodeEntity(id: newGroupNodeId.id,
                                position: center,
                                zIndex: self.highestZIndex + 1,
                                parentGroupNodeId: self.graphUI.groupNodeFocused?.asNodeId,
                                patchNodeEntity: nil,
                                layerNodeEntity: nil,
                                isGroupNode: true,
                                title: NodeKind.group.getDisplayTitle(customName: nil),
                                // Syncs inputs later
                                inputs: [])
        
        let newGroupNode = NodeViewModel(from: schema,
                                         activeIndex: self.activeIndex,
                                         graphDelegate: self)
        
        self.visibleNodesViewModel.nodes.updateValue(newGroupNode, 
                                                     forKey: newGroupNode.id)
        
        return newGroupNode
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
//        let selectedNodeIds = state.selectedNodeIds
        let selectedCanvasItems = state.selectedCanvasItems
        let edges = state.createEdges()

//        #if DEV || DEV_DEBUG
//        // Every selected node must belong to this traversal level.
        let nodesAtThisLevel = state.getVisibleNodes().map(\.id).toSet
        if state.selectedNodeIds.contains(where: { selectedNodeId in !nodesAtThisLevel.contains(selectedNodeId) }) {
            fatalErrorIfDebug()
        }
//        #endif

        let (inputEdgesToUpdate,
             outputEdgesToUpdate) = state.getEdgesToUpdate(
                selectedCanvasItems: selectedCanvasItems.map(\.id).toSet,
                edges: edges)

        // log("GroupNodeCreatedEvent: inputEdgesToUpdate: \(inputEdgesToUpdate)")
        // log("GroupNodeCreatedEvent: outputEdgesToUpdate: \(outputEdgesToUpdate)")

        let center = state.graphUI.center(state.localPosition)
        
        //input splitters need to be west of the `to` node for the `edge`
        var oldEdgeToNodeLocations = state.getInitialOldEdgeToNodeLocations(inputEdgesToUpdate: inputEdgesToUpdate)
                                                                
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
        
        var oldEdgeFromNodeLocations = state.getInitialOldEdgeFromNodeLocations(outputEdgesToUpdate: outputEdgesToUpdate)
        
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
        
        // Update selected canvas items with new parent id
        selectedCanvasItems.forEach { $0.parentGroupNodeId = newGroupNodeId.id }
        
        // Create the actual GroupNode itself
        let newGroupNode = state.createGroupNode(newGroupNodeId: newGroupNodeId,
                                                 center: center)

        // wipe selected edges and canvas items
        state.graphUI.selection = GraphUISelectionState()
        state.selectedEdges = .init()
        state.resetSelectedCanvasItems()
        
        // ... then select the GroupNode and its edges
        // TODO: highlight new group node's incoming and outgoing edges
        newGroupNode.select()

        // Stop any active node dragging etc.
        state.graphMovement.stopNodeMovement()

        // Recalculate graph
        state.initializeGraphComputation()
        
        return .persistenceResponse
    }
}

extension GraphMovementObserver {
    func stopNodeMovement() {
        self.draggedCanvasItem = nil
        self.lastCanvasItemTranslation = .zero
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
