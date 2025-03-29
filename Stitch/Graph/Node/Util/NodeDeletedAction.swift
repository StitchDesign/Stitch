//
//  NodeDeletedAction.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/5/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Used for Delete key shortcut
struct DeleteShortcutKeyPressed: StitchDocumentEvent {
    
    func handle(state: StitchDocumentViewModel) {
        let graph = state.visibleGraph
        
        // Check which we have focused: layers or canvas items
        if state.visibleGraph.layersSidebarViewModel.isSidebarFocused {
            graph.layersSidebarViewModel.deleteSelectedItems()
            graph.updateInspectorFocusedLayers()
        }
        
        // If no layers actively selected, then assume canvas items may be selected
        else {
            
            // delete comment boxes
            graph.deleteSelectedCommentBoxes()

            // delete nodes
            graph.selectedGraphNodesDeleted(
                selectedNodes: graph.selectedCanvasItems)
        }
                
        state.encodeProjectInBackground()
    }
}

// Used by Node Tag Menu 'delete' option
struct SelectedGraphNodesDeleted: StitchDocumentEvent {

    var canvasItemId: CanvasItemId? // for when node tag menu opened via right-click

    func handle(state: StitchDocumentViewModel) {
        let graph = state.visibleGraph
        
        if graph.getSelectedCanvasItems(groupNodeFocused: state.groupNodeFocused?.groupNodeId).isEmpty,
           let canvasItemId = canvasItemId {
            graph.selectCanvasItem(canvasItemId)
        }

        graph.selectedGraphNodesDeleted(
            selectedNodes: graph.selectedCanvasItems)

        state.encodeProjectInBackground()
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

        self.graphMovement.draggedCanvasItem = nil
        
        self.updateGraphData()
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

            let inputPort: LayerInputObserver = layerNode[keyPath: x.keyPath.layerInput.layerNodeKeyPath]
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
                  let outputData: OutputLayerNodeRowData = layerNode.outputPorts[safe: x.portId] else {
                fatalErrorIfDebug()
                return
            }
            
            // Find this output's downstream connected nodes,
            // look at each node's inputs,
            // and remove the upstreamOutputCoordinate reference if it was for this deleted layer canvas output.
            outputData.rowObserver.getConnectedDownstreamNodes().forEach { (downstreamCanvasItem: CanvasItemViewModel) in
                downstreamCanvasItem.inputViewModels.forEach { (inputRow: InputNodeRowViewModel) in
                    if let upstreamCoordinate = inputRow.rowDelegate?.upstreamOutputCoordinate,
                       upstreamCoordinate.nodeId == x.node,
                       upstreamCoordinate.portId == x.portId {
                        inputRow.rowDelegate?.upstreamOutputCoordinate = nil
                    }
                }
            }
            
            outputData.canvasObserver = nil
        }
    }
    
    @MainActor
    func deleteNode(id: NodeId,
                    willDeleteLayerGroupChildren: Bool = true) {

        //    log("deleteNode called, will delete node \(id)")
        
        guard let node = self.getNodeViewModel(id),
              let graph = node.graphDelegate else {
            log("deleteNode: node not found")
            return
        }
        
        let isLayer = node.kind.isLayer
        
        // Find nodes to recursively delete
        switch node.kind {
        case .layer(let layer):
            
            // May need to remove the layer-group's children
            if layer == .group {
                if willDeleteLayerGroupChildren {
                    let layerChildren = self.getLayerChildren(for: id)
                    layerChildren.forEach {
                        self.deleteNode(id: $0)
                    }
                }
            }
            
            // If we delete a layer, update any inputs that were using that layer for `PortValue.assignedLayer`.
            // Note: can't just look at interaction patch node's first input or a layer node's pinTo input, since e.g. a splitter could have nodeType = assignedLayer
            self.nodes.values.forEach { (_node: NodeViewModel) in
                _node.inputsObservers.forEach { inputObserver in
                    inputObserver.values = inputObserver.values.map({ value in
                        if let layerId = value.getInteractionId,
                           layerId == id.asLayerNodeId {
                            return .assignedLayer(nil)
                        } else if let pinToId = value.getPinToId,
                                case let .layer(x) = pinToId,
                                x == id.asLayerNodeId {
                            return .pinTo(.parent)
                        } else {
                            return value
                        }
                    })
                }
            }
          
        case .group:
            let groupChildren = self.getGroupNodeChildren(for: id)
            groupChildren.forEach {
//                self.deleteNode(id: $0)
                self.deleteCanvasItem($0)
            }
            
        case .patch(let patch) where patch == .splitter:
            // Resize group node given new fields
            if let groupNodeId = node.patchCanvasItem?.parentGroupNodeId,
               let groupCanvasNode = self.getNodeViewModel(groupNodeId)?.patchCanvasItem {
                groupCanvasNode.resetViewSizingCache()
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
                    graph.enabledCameraNodeIds.remove(id)
                }
            default:
                break
            }
        }

        // Update comment box data
        self.deleteCommentBox(id)
        
        // Delete media from file manager if it's the "source" media and unused elsewhere
        node.inputs.findImportedMediaKeys().forEach { mediaKey in
            self.checkToDeleteMedia(mediaKey, from: node.id)
        }

        // Update sidebar
        if isLayer {
            self.layersSidebarViewModel.deleteItems(from: Set([id]))
        }
    }
    
    /// Checks if some media is used elsewhere before proceeding to delete.
    @MainActor
    func checkToDeleteMedia(_ mediaKey: MediaKey,
                            from nodeId: NodeId) {
        // Check media in other places
        let allOtherMedia = self.nodes.values.reduce(into: Set<MediaKey>()) { result, node in
            guard node.id != nodeId else { return }
            
            let allMediaHere = node.inputs.findImportedMediaKeys().toSet
            result = result.union(allMediaHere)
        }
        
        // Safe to delete if other nodes don't use specified media
        let isMediaUsedElsewhere = allOtherMedia.contains(mediaKey)
        if !isMediaUsedElsewhere {
            self.mediaLibrary.removeValue(forKey: mediaKey)

            Task { [weak self] in
                await self?.documentEncoderDelegate?
                    .deleteMediaFromNode(mediaKey: mediaKey)
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
