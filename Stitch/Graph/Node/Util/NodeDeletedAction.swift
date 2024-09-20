//
//  NodeDeletedAction.swift
//  prototype
//
//  Created by Christian J Clampitt on 8/5/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Used for Delete key shortcut
struct DeleteShortcutKeyPressed: GraphEventWithResponse {
    
    func handle(state: GraphState) -> GraphResponse {

        // Check which we have focused: layers or canvas items
        
        let activelySelectedLayers = state.sidebarSelectionState.inspectorFocusedLayers.activelySelected
        
        if !activelySelectedLayers.isEmpty {
            state.sidebarSelectedItemsDeletingViaEditMode()
            state.updateInspectorFocusedLayers()
        }
        
        // If no layers actively selected, then assume canvas items may be selected
        else {
            
            // delete comment boxes
            state.deleteSelectedCommentBoxes()

            // delete nodes
            state.selectedGraphNodesDeleted(
                selectedNodes: state.selectedNodeIds)
        }
                
        return .shouldPersist
    }
}

// Used by Node Tag Menu 'delete' option
struct SelectedGraphNodesDeleted: GraphEventWithResponse {

    var canvasItemId: CanvasItemId? // for when node tag menu opened via right-click

    func handle(state: GraphState) -> GraphResponse {
        
        if state.selectedCanvasItems.isEmpty,
           let canvasItemId = canvasItemId,
           let canvasItem = state.getCanvasItem(canvasItemId) {
            canvasItem.select()
        }

        state.selectedGraphNodesDeleted(
            selectedNodes: state.selectedNodeIds)

        return .shouldPersist
    }
}


extension GraphState {
    // Preferred way to delete node(s); deletes each individual node and intelligently handles batch operations
    @MainActor
    func selectedGraphNodesDeleted(selectedNodes: CanvasItemIdSet) {

        selectedNodes.forEach { canvasItemId in
            self.deleteCanvasItem(canvasItemId)
        }
            
        // reset node-ui highlight/selection state
        self.graphUI.selection = GraphUISelectionState()

        // reset selected edges;
        // NOTE: it's safe to completely reset these, since we only select edges for selected nodes,
        // and so deleting the selected nodes means de-selecting those associated edges)
        self.selectedEdges = .init()

        // BATCH OPERATION: Update sidebar state ONCE, after deleting all nodes
        // Recreate topological order
        self.documentDelegate?.updateTopologicalData()

        self.graphMovement.draggedCanvasItem = nil
        
        self.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: self.sidebarListState,
            expanded: self.getSidebarExpandedItems(),
            graphState: self)
    }
    
    // Varies by node vs LayerInputOnGraph vs comment box
    @MainActor
    func deleteCanvasItem(_ id: CanvasItemId) {
        switch id {
            
        case .node(let x):
            self.deleteNode(id: x)
        
        case .layerInput(let x):
            // Set the canvas-ui-data on the layer node's input = nil
            guard let layerNode = self.getNodeViewModel(x.node)?.layerNode else {
                fatalErrorIfDebug()
                return
            }

            let inputPort = layerNode[keyPath: x.keyPath.layerInput.layerNodeKeyPath]
            let prevPackMode = inputPort.mode
            
            layerNode[keyPath: x.keyPath.layerNodeKeyPath].canvasObserver = nil
            
            // Remove conection
            layerNode[keyPath: x.keyPath.layerNodeKeyPath].rowObserver.upstreamOutputCoordinate = nil
            
            // Check if packed mode changed
            let newPackMode = inputPort.mode
            if prevPackMode != newPackMode {
                inputPort.wasPackModeToggled()
            }
            
        case .layerOutput(let x):
            // Set the canvas-ui-data on the layer node's input = nil
            guard let layerNode = self.getNodeViewModel(x.node)?.layerNode,
                  let outputData = layerNode.outputPorts[safe: x.portId] else {
                fatalErrorIfDebug()
                return
            }
            
            outputData.canvasObserver = nil
        }
    }
    
    @MainActor
    func deleteNode(id: NodeId,
                    willDeleteLayerGroupChildren: Bool = true) {

        //    log("deleteNode called, will delete node \(id)")
        
        guard let node = self.getNodeViewModel(id) else {
            log("deleteNode: node not found")
            return
        }
        
        // Find nodes to recursively delete
        switch node.kind {
        case .layer(let layer) where layer == .group:
            if willDeleteLayerGroupChildren {
                let layerChildren = self.getLayerChildren(for: id)
                layerChildren.forEach {
                    self.deleteNode(id: $0)
                }
            }
            
        case .group:
            let groupChildren = self.getGroupChildren(for: id)
            groupChildren.forEach {
                self.deleteNode(id: $0)
            }
            
        default:
            break
        }
        
        // Delete this node from view model
        self.visibleNodesViewModel.nodes.removeValue(forKey: id)
        
        // MARK: - Media effects below
        // Teardown options for singleton media nodes (location + camera)
        if let singletonMediaType = node.kind.singletonMediaOption {
            // Update undo events to re-create media for singleton
            switch singletonMediaType {
            case .patch(.location):
                let lastOfNode = !self.nodes.values
                    .contains { $0.patch == .location }

                // Tear down location when last of this node is deleted
                if lastOfNode {
                    self.documentDelegate?.teardownSingleton(keyPath: \.locationManager)
                }
            case .patch(.cameraFeed), .layer(.realityView):
                // Check if we deleted the last of some camera-supported node
                let lastOfNode = !Array(self.nodes.values)
                    .contains(where: { [.patch(.cameraFeed), .layer(.realityView)].contains($0.kind) })

                if lastOfNode {
                    // Update CameraFeedManager with latest enabled nodes--conditional tear down handled there
                    self.documentDelegate?.removeCameraNode(id: id)
                }
            default:
                break
            }
        }

        // Update comment box data
        self.deleteCommentBox(id)
        
        // Delete media from file manager if it's the "source" media
        node.inputs.findImportedMediaKeys().forEach { mediaKey in
            self.mediaLibrary.removeValue(forKey: mediaKey)
            
            Task { [weak self] in
                await self?.documentEncoder.deleteMediaFromNode(mediaKey: mediaKey)
            }
        }
    }
}

extension CommentBoxesDict {
    // Removes a node from any the node-set of any comment boxes that have it
    // Note: comment-boxes-bounds-dict does not contain node if
    func removeNode(_ nodeId: CanvasItemId) {
        self.values.forEach { box in
            box.nodes.remove(nodeId)
        }
    }
}
