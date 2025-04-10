//
//  NodeCreatedAction.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/5/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreMotion

struct NodeCreatedEvent: StitchDocumentEvent {
    
    let choice: NodeKind
    
    func handle(state: StitchDocumentViewModel) {
        guard let node = state.nodeInserted(choice: choice) else {
            fatalErrorIfDebug()
            return
        }
        state.visibleGraph.persistNewNode(node)
    }
}

extension GraphState {
    @MainActor
    func nodeCreated(choice: NodeKind) -> NodeViewModel? {
        self.documentDelegate?.nodeInserted(choice: choice)
    }
}

extension StitchDocumentViewModel {
    
    /// Only for insert-node-menu creation of nodes; shortcut key creation of nodes uses `viewPortCenter`
    @MainActor
    var newCanvasItemInsertionLocation: CGPoint {
        if let doubleTapLocation = self.doubleTapLocation {
            log("newNodeCenterLocation: had doubleTapLocation: \(doubleTapLocation)")
            return adjustPositionToMultipleOf(doubleTapLocation)
        } else {
            var center = self.viewPortCenter
            center.x -= self.adjustmentFromOpenLayerInspector
            return center
        }
    }
    
    @MainActor
    private var adjustmentFromOpenLayerInspector: CGFloat {
        guard self.storeDelegate?.showsLayerInspector ?? false else {
            return 0
        }
        
        let inspectorWidth = LayerInspectorView.LAYER_INSPECTOR_WIDTH
        let scale = self.graphMovement.zoomData
        
        // TODO: why only half the inspector's width?
        return inspectorWidth/2 * 1/scale
    }

    /// Current center of user's view onto the graph
    @MainActor
    var viewPortCenter: CGPoint {
        let localPosition = self.graphMovement.localPosition
        let scale = self.graphMovement.zoomData
        let viewPortFrame = self.frame
        
        // Apply scale to the viewPort-centering
        let scaledViewPortFrame = CGPoint(
            x: viewPortFrame.width/2 * 1/scale,
            y: viewPortFrame.height/2 * 1/scale
        )
        
        // UIScrollView's .contentOffset needs to have its .zoomScale factored out
        // https://stackoverflow.com/questions/3051361/how-much-contentoffset-changes-in-uiscrollview-for-zooming
        let descaledLocalPosition = CGPoint(
            x: localPosition.x / scale,
            y: localPosition.y / scale
        )
                
        let center = CGPoint(
            x: descaledLocalPosition.x + scaledViewPortFrame.x,
            y: descaledLocalPosition.y + scaledViewPortFrame.y
        )

        // Finally: adjust the position to sit on our grid
        let centerAdjustedForGrid = adjustPositionToMultipleOf(center)
        
        return centerAdjustedForGrid
    }

    // Used by InsertNodeMenu
    @MainActor
    func nodeInserted(choice: NodeKind,
                      // For LLMStep Actions
                      nodeId: UUID? = nil) -> NodeViewModel? {

        let nodeCenter = self.newCanvasItemInsertionLocation
        
        guard let node = self.visibleGraph.createNode(
                graphTime: self.graphStepManager.graphStepState.graphTime,
                newNodeId: nodeId ?? UUID(),
                highestZIndex: self.visibleGraph.highestZIndex,
                choice: choice,
                center: nodeCenter) else {
            log("nodeCreated: could not create node for \(choice)")
            fatalErrorIfDebug()
            return nil
        }

        self.handleNewlyCreatedNode(node: node)
        return node
    }
   
    // Used by insert-node-menu and sidebar-group-creation
    @MainActor
    func handleNewlyCreatedNode(node: NodeViewModel) {

        // Note: DO NOT RESET THE ACTIVE NODE MENU SELECTION UNTIL ANIMATION HAS COMPLETED
        // Reset selection for insert node menu
        // self.insertNodeMenuState.activeSelection = InsertNodeMenuState.allSearchOptions.first

        node.getAllCanvasObservers().forEach {
            $0.parentGroupNodeId = self.groupNodeFocused?.groupNodeId
        }
        self.visibleGraph.visibleNodesViewModel.nodes.updateValue(node, forKey: node.id)
        
        // TODO: if we calculate the graph BEFORE we "initialize the delegate", would graph eval "fail"?
        node.initializeDelegate(graph: self.visibleGraph,
                                document: self)
        
        self.visibleGraph.calculateFullGraph()
        
        // Reset nodes layout cache
        self.visibleGraph.visibleNodesViewModel.resetCache()
        
        // Reset doubleTapLocation
        // TODO: where else would we need to reset this?

        // Do this once the node-insert animation has finished
        //    self.doubleTapLocation = nil

        self.graphMovement.draggedCanvasItem = nil
    }
}

extension GraphState {

    @MainActor
    func createNode(graphTime: TimeInterval,
                    newNodeId: NodeId = NodeId(),
                    highestZIndex: ZIndex,
                    choice: NodeKind,
                    center: CGPoint) -> NodeViewModel? {
        //    log("createNode called")

        // increment the "highest z-index", and then use that for next node
        switch choice {

        case .group:
            fatalErrorIfDebug("createNode: unexpectedly had Group node for NodeKind choice; exiting early")
            return nil

        // TODO: break this logic up into smaller, separate functions,
        // creating a layer node vs creating a patch node.
        case let .layer(layer):
            return self.createLayerNode(layer: layer,
                                        newNodeId: newNodeId,
                                        center: center)
            
        case let .patch(patch):
            return patch.defaultNode(id: newNodeId,
                                     position: center,
                                     zIndex: highestZIndex + 1,
                                     graphTime: graphTime,
                                     graphDelegate: self)
        }
    }
    
    @MainActor
    private func createLayerNode(layer: Layer,
                                 newNodeId: NodeId,
                                 center: CGPoint) -> NodeViewModel? {
        // just add directly to end of layer nodes list (ordered-dict)
        guard let layerNode = layer.defaultNode(
                id: newNodeId,
                position: center.toCGSize,
                zIndex: highestZIndex + 1,
                graphDelegate: self) else {
            fatalErrorIfDebug()
            return nil
        }
        
        // Update sidebar data
        var sidebarLayerData = SidebarLayerData(id: layerNode.id)
        
        // Creates group node data for reality node
        if layerNode.isGroupLayer {
            sidebarLayerData.children = []
            sidebarLayerData.isExpandedInSidebar = true
        }
        
        var newSidebarData = self.layersSidebarViewModel.createdOrderedEncodedData()
        newSidebarData.insert(sidebarLayerData, at: 0)
        self.layersSidebarViewModel.update(from: newSidebarData)
        
        // Focus this, and only this, layer node in inspector
        self.layersSidebarViewModel.resetEditModeSelections()
        self.layersSidebarViewModel.sidebarItemSelectedViaEditMode(sidebarLayerData.id)
        self.layersSidebarViewModel.selectionState.lastFocused = sidebarLayerData.id
        self.resetSelectedCanvasItems()
        
        return layerNode
    }
    
    // TODO: what about e.g. duplicating a camera patch node? Duplication does not use `persistNewNode`
    @MainActor
    func persistNewNode(_ node: PatchNode) {
        var undoEvents = [Action]()
        
        // Undo event needed for camera feed to update manager if camera feed addition is undo'd
        if node.kind == .patch(.cameraFeed) {
            undoEvents.append(CameraFeedNodeDeleted(nodeId: node.id))
        }
        
        self.encodeProjectInBackground(undoEvents: undoEvents)
    }
}
