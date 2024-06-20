//
//  NodeDeletedAction.swift
//  prototype
//
//  Created by Christian J Clampitt on 8/5/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO: can be a `GraphEventWithResponse`
// Used for Delete key shortcut
struct SelectedGraphItemsDeleted: GraphEventWithResponse {
    
    func handle(state: GraphState) -> GraphResponse {

        // delete comment boxes
        state.deleteSelectedCommentBoxes()

        // delete nodes
        state.selectedGraphNodesDeleted(
            selectedNodes: state.selectedNodeIds)
        
        state.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: state.sidebarListState,
            expanded: state.getSidebarExpandedItems(),
            graphState: state)
        
        return .shouldPersist
    }
}

// Still used for node tag menu's Delete option?
struct SelectedGraphNodesDeleted: GraphEventWithResponse {

    var nodeId: NodeId? // for when node tag menu opened via right-click

    func handle(state: GraphState) -> GraphResponse {
        
        if state.selectedNodeIds.isEmpty,
           let nodeId = nodeId,
           let node = state.getNodeViewModel(nodeId) {
            node.select()
        }

        state.selectedGraphNodesDeleted(
            selectedNodes: state.selectedNodeIds)

        return .shouldPersist
    }
}

extension GraphState {
    // Preferred way to delete node(s); deletes each individual node and intelligently handles batch operations
    @MainActor
    func selectedGraphNodesDeleted(selectedNodes: IdSet) {

        self.selectedNodeIds.forEach {
            self.deleteNode(id: $0)
        } // for id in ...

        // reset node-ui highlight/selection state
        self.graphUI.selection = GraphUISelectionState()

        // reset selected edges;
        // NOTE: it's safe to completely reset these, since we only select edges for selected nodes,
        // and so deleting the selected nodes means de-selecting those associated edges)
        self.selectedEdges = .init()

        // BATCH OPERATION: Update sidebar state ONCE, after deleting all nodes
        // Recreate topological order
        self.updateTopologicalData()

        self.graphMovement.draggedNode = nil
        
        self.updateSidebarListStateAfterStateChange()
        
        // TODO: why is this necessary?
        _updateStateAfterListChange(
            updatedList: self.sidebarListState,
            expanded: self.getSidebarExpandedItems(),
            graphState: self)
    }

    @MainActor
    func deleteNode(id: NodeId,
                    willDeleteLayerChildren: Bool = true) {

        //    log("deleteNode called, will delete node \(id)")
        
        guard let node = self.getNodeViewModel(id) else {
            log("deleteNode: node not found")
            return
        }
        
        // Find nodes to recursively delete
        switch node.kind {
        case .layer(let layer) where layer == .group:
            if willDeleteLayerChildren {
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
                    self.teardownSingleton(keyPath: \.locationManager)
                }
            case .patch(.cameraFeed), .layer(.realityView):
                // Check if we deleted the last of some camera-supported node
                let lastOfNode = !Array(self.nodes.values)
                    .contains(where: { [.patch(.cameraFeed), .layer(.realityView)].contains($0.kind) })

                if lastOfNode {
                    // Update CameraFeedManager with latest enabled nodes--conditional tear down handled there
                    self.removeCameraNode(id: id)
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
    func removeNode(_ nodeId: NodeId) {
        self.values.forEach { box in
            box.nodes.remove(nodeId)
        }
    }
}
