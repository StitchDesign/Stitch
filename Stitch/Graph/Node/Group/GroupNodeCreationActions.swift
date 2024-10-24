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
            
            let destinationIsInsideGroup = allImpliedIds.contains(edge.to.inputCoordinateAsCanvasItemId)
            
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
    
    @MainActor
    func getInitialOldEdgeToNodeLocations(inputEdgesToUpdate: Edges) -> [NodeIOCoordinate: CGPoint] {
        var oldEdgeToNodeLocations = [NodeIOCoordinate: CGPoint]()
        inputEdgesToUpdate.forEach { edge in
            if let node = self.getCanvasItem(inputId: edge.to) {
                // Move west
                var position = node.position
                position.x -= (200 + node.sizeByLocalBounds.width)
                oldEdgeToNodeLocations[edge.to] = position
            }
        }
        return oldEdgeToNodeLocations
    }
    
    @MainActor
    func getInitialOldEdgeFromNodeLocations(outputEdgesToUpdate: Edges) -> [NodeIOCoordinate: CGPoint] {
        var oldEdgeFromNodeLocations = [NodeIOCoordinate: CGPoint]()
        outputEdgesToUpdate.forEach { edge in
            if let node = self.getCanvasItem(outputId: edge.from) {
                // Move east
                var position = node.position
                position.x += (200 + node.sizeByLocalBounds.width)
                oldEdgeFromNodeLocations[edge.from] = position
            }
        }
        return oldEdgeFromNodeLocations
    }
    
    @MainActor
    func createGroupNode(newGroupNodeId: NodeId,
                         center: CGPoint,
                         isComponent: Bool) async -> NodeViewModel {
        guard let document = self.documentDelegate else {
            fatalErrorIfDebug()
            return .createEmpty()
        }
        
        // If current focused group is component, make parent node ID nil as we're creating a new graph state
        let focusedGroupNodeId = self.graphUI.groupNodeFocused?.groupNodeId
        
        let canvasEntity = CanvasNodeEntity(position: center,
                                            zIndex: self.highestZIndex + 1,
                                            parentGroupNodeId: focusedGroupNodeId)
        
        // Create new canvas entity if specified
        let nodeType: NodeTypeEntity = isComponent ? .component(.init(componentId: newGroupNodeId,
                                                                      inputs: [],   // create ports later
                                                                      canvasEntity: canvasEntity))
                                                   : .group(canvasEntity)
        
        let schema = NodeEntity(id: newGroupNodeId,
                                nodeTypeEntity: nodeType,
                                title: NodeKind.group.getDisplayTitle(customName: nil))
        
        let newGroupNode = await NodeViewModel(from: schema,
                                               graphDelegate: self,
                                               document: document)
        
        self.visibleNodesViewModel.nodes.updateValue(newGroupNode, 
                                                     forKey: newGroupNode.id)
        
        return newGroupNode
    }
}

extension StitchDocumentViewModel {
    /** Event for creating a group node, which does the following:
     * 1. Determines incoming and outgoing edges to group, whose connections
     *      will need to change to new group node.
     * 2. Creates input and output group nodes.
     * 3. Removes old edges and connections and updates them to new group nodes.
     */
    @MainActor
    func createGroup(isComponent: Bool) async {
        guard !self.llmRecording.isRecording else {
            log("Do not create GroupNodes during LLM Recording")
            return
        }
        
        let newGroupNodeId = NodeId()
        let selectedCanvasItems = self.visibleGraph.selectedCanvasItems
        let edges = self.visibleGraph.createEdges()
        let center = self.graphUI.center(self.localPosition)

        // Every selected node must belong to this traversal level.
        let nodesAtThisLevel = self.visibleGraph.getVisibleCanvasItems().map(\.id).toSet
        
        assertInDebug(!self.visibleGraph.selectedNodeIds.contains(where: { selectedNodeId in !nodesAtThisLevel.contains(selectedNodeId) }))
        
        // Update selected canvas items with new parent id
        // Components are set with nil because of new graph state
        selectedCanvasItems.forEach { $0.parentGroupNodeId = isComponent ? nil : newGroupNodeId }

        // Encode component files if specified
        if isComponent {
            // MARK: must create component before calling createGroupNode below
            await self.createNewMasterComponent(selectedCanvasItems: selectedCanvasItems,
                                                componentId: newGroupNodeId)
        }
        
        // Create the actual GroupNode itself
        let newGroupNode = await self.visibleGraph
            .createGroupNode(newGroupNodeId: newGroupNodeId,
                             center: center,
                             isComponent: isComponent)
        
        //input splitters need to be west of the `to` node for the `edge`
        self.visibleGraph.createSplitterForNewGroup(splitterType: .input,
                                                    selectedCanvasItems: selectedCanvasItems,
                                                    edges: edges,
                                                    newGroupNodeId: newGroupNodeId,
                                                    isComponent: isComponent,
                                                    center: center)
        
        // output edge = an edge going FROM a node in the group, TO a node outside the group
        self.visibleGraph.createSplitterForNewGroup(splitterType: .output,
                                                    selectedCanvasItems: selectedCanvasItems,
                                                    edges: edges,
                                                    newGroupNodeId: newGroupNodeId,
                                                    isComponent: isComponent,
                                                    center: center)
        
        // Delete items from original graph since selected items have been copied
        // to new component graph
        if isComponent {
            selectedCanvasItems.forEach {
                // TODO: consider layer behavior when selected layers are involved
                guard let node = $0.nodeDelegate as? NodeViewModel else {
                    fatalErrorIfDebug()
                    return
                }
                
                self.visibleGraph.deleteNode(id: node.id)
            }
        }

        // wipe selected edges and canvas items
        self.graphUI.selection = GraphUISelectionState()
        self.visibleGraph.selectedEdges = .init()
        self.visibleGraph.resetSelectedCanvasItems()
        
        // ... then select the GroupNode and its edges
        newGroupNode.patchCanvasItem?.select()

        // Stop any active node dragging etc.
        self.graphMovement.stopNodeMovement()
        
        // Updates graph data in VisibleNodesViewModel
        if let encoderDelegate = self.visibleGraph.documentEncoderDelegate {
            self.visibleGraph.initializeDelegate(document: self,
                                                 documentEncoderDelegate: encoderDelegate)
        } else {
            fatalErrorIfDebug()
        }

        // Recalculate graph
        self.graph.updateGraphData()
        
        self.visibleGraph.encodeProjectInBackground()
    }
    
    /// Updates graph state with brand new component, not yet creating a node view model.
    @MainActor
    func createNewMasterComponent(selectedCanvasItems: [CanvasItemViewModel],
                                  componentId: NodeId) async {
        let selectedNodeIds = selectedCanvasItems.compactMap { $0.nodeDelegate?.id }.toSet
        let result = self.createNewStitchComponent(componentId: componentId,
                                                   groupNodeFocused: self.graphUI.groupNodeFocused,
                                                   selectedNodeIds: selectedNodeIds)
 
        // Create new published component matching draft
        let masterComponent = StitchMasterComponent(componentData: result.component,
                                                    parentGraph: self.visibleGraph)
        
        assertInDebug(result.component.id == componentId)
        self.visibleGraph.components.updateValue(masterComponent,
                                                 forKey: result.component.id)
        
        // Copy to disk and publish
        do {
            try await masterComponent.encoder
                .encodeNewComponent(result)
        } catch {
            fatalErrorIfDebug(error.localizedDescription)
        }
    }
}

extension GraphState {
    @MainActor func createSplitterForNewGroup(splitterType: SplitterType,
                                              selectedCanvasItems: CanvasItemViewModels,
                                              edges: [PortEdgeData],
                                              newGroupNodeId: NodeId,
                                              isComponent: Bool,
                                              center: CGPoint) {
        let (inputEdgesToUpdate,
             outputEdgesToUpdate) = self.getEdgesToUpdate(
                selectedCanvasItems: selectedCanvasItems.map(\.id).toSet,
                edges: edges)
        
        var oldEdgeLocations = splitterType == .input ?
        self.getInitialOldEdgeToNodeLocations(inputEdgesToUpdate: inputEdgesToUpdate) :
        self.getInitialOldEdgeFromNodeLocations(outputEdgesToUpdate: outputEdgesToUpdate)
        
        let edgesToUpdate = splitterType == .input ? inputEdgesToUpdate : outputEdgesToUpdate
        
        edgesToUpdate.enumerated().forEach { portId, edge in
            
            // Retrieve relevant old-edge's destination node's position
            let port: NodeIOCoordinate = splitterType == .input ? edge.to : edge.from
            var nodePosition = oldEdgeLocations.get(port) ?? center
            
            self.insertIntermediaryNode(
                inBetweenNodesOf: edge,
                newGroupNodeId: newGroupNodeId,
                isComponent: isComponent,
                splitterType: splitterType,
                portId: portId,
                position: nodePosition)
            
            // Increment node position for next input splitter node
            nodePosition.x += NODE_POSITION_STAGGER_SIZE
            nodePosition.y += NODE_POSITION_STAGGER_SIZE
            
            oldEdgeLocations[port] = nodePosition
        }
    }


    // Helper method which, given an edge, updates state so that a middle-man
    // node is connected to the `from` and `to` coordinates. Used for
    // inserting input and output group nodes.

    // formerly `insertIntermediaryNode`
    @MainActor
    func insertIntermediaryNode(inBetweenNodesOf oldEdge: PortEdgeData,
                                newGroupNodeId: NodeId,
                                isComponent: Bool,
                                splitterType: SplitterType,
                                portId: Int,
                                position: CGPoint) {

        // log("insertIntermediaryNode: oldEdge: \(oldEdge)")
        
        let newSplitterNodeId = NodeId()
        
        // Ignores connections from new splitter node to new component
//        let willCreateNewInputConnection = !(isComponent && splitterType == .output)
//        let willCreateNewOutputConnection = !(isComponent && splitterType == .input)
        
        // Components create connections to parent group node
        let newConnectionPortId: NodeIOCoordinate = isComponent ?
            .init(portId: portId,
                  nodeId: newGroupNodeId) :
            .init(portId: 0,
                  nodeId: newSplitterNodeId)

        guard outputExists(oldEdge.from) else {
            log("insertIntermediaryNode: Couldn't get output while making input group node.")
            return
        }

        // CREATE AND INSERT GROUP SPLITTER NODE

        // TODO: create initializer that can receive `position` and `splitterType`?
        let newSplitterNode = SplitterPatchNode.createViewModel(
            id: newSplitterNodeId,
            position: position,
            zIndex: self.highestZIndex + 1,
            parentGroupNodeId: GroupNodeId(newGroupNodeId),
            graphDelegate: self)

        newSplitterNode.patchCanvasItem?.position = position
        newSplitterNode.patchCanvasItem?.previousPosition = position

        guard let splitterNode = newSplitterNode.patchNode else {
            fatalErrorIfDebug()
            return
        }
        
        splitterNode.splitterType = splitterType
        
        // Slightly modify date for consistent port ordering
        let lastModifiedDate = splitterNode.splitterNode?.lastModifiedDate ?? Date.now
        splitterNode.splitterNode?.lastModifiedDate = lastModifiedDate
            .addingTimeInterval(Double(portId) * 0.01)

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
//        if willCreateNewInputConnection {
            self.addEdgeWithoutGraphRecalc(
                from: oldEdge.from,
                to: newConnectionPortId)
//        }

        // Create edge from new splitter node to downstream node of old connection
//        if willCreateNewOutputConnection {
            self.addEdgeWithoutGraphRecalc(
                from: newConnectionPortId,
                to: oldEdge.to)
//        }
    }

    @MainActor
    func outputExists(_ output: OutputCoordinate) -> Bool {
        self.getPatchNode(id: output.nodeId)?
            .getOutputRowObserver(for: output.portType)
            .isDefined ?? false
    }

}
