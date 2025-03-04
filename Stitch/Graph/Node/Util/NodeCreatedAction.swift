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
        guard let node = state.nodeCreated(choice: choice) else {
            fatalErrorIfDebug()
            return
        }
        state.visibleGraph.persistNewNode(node)
    }
}

extension GraphState {
    @MainActor
    func nodeCreated(choice: NodeKind) -> NodeViewModel? {
        self.documentDelegate?.nodeCreated(choice: choice)
    }
}

extension StitchDocumentViewModel {
    
    /// Only for insert-node-menu creation of nodes; shortcut key creation of nodes uses `viewPortCenter`
    @MainActor
    var newNodeCenterLocation: CGPoint {
        if let doubleTapLocation = self.doubleTapLocation {
            log("newNodeCenterLocation: had doubleTapLocation: \(doubleTapLocation)")
            return adjustPositionToMultipleOf(doubleTapLocation)
        } else {
            return self.viewPortCenter
        }
    }
    
    @MainActor
    var newLayerPropertyLocation: CGPoint {
        var center = self.viewPortCenter

        // Slightly move off-center, since preview window can often partially cover up the just added property
        center.x -= CGFloat(SQUARE_SIDE_LENGTH * 6)
        
        return center
    }

    @MainActor
    private func hasRealityNode() -> Bool {
        return self.visibleGraph.visibleNodesViewModel.nodes.values.contains { node in
            if case .layer(.realityView) = node.kind {
                return true
            }
            return false
        }
    }
    
    @MainActor
    private func hasCameraNode() -> Bool {
        return self.visibleGraph.visibleNodesViewModel.nodes.values.contains { node in
            if case .patch(.cameraFeed) = node.kind {
                return true
            }
            return false
        }
    }

    // Used by InsertNodeMenu
    @MainActor
    func nodeCreated(choice: NodeKind,
                     nodeId: UUID? = nil,
                     center: CGPoint? = nil) -> NodeViewModel? {
        // Check for reality and camera nodes
        if case .layer(.realityView) = choice {
            if hasCameraNode() || hasRealityNode(){
                dispatch(ReceivedStitchFileError(error: .cameraBasedNodeExists))
                return nil
            }
        } else if case .patch(.cameraFeed) = choice {
            if hasRealityNode() || hasCameraNode() {
                dispatch(ReceivedStitchFileError(error: .cameraBasedNodeExists))
                return nil
            }
        }
        
        let nodeCenter = center ?? self.newNodeCenterLocation
        
        guard let node = self.createNode(
                graphTime: self.graphStepManager.graphStepState.graphTime,
                newNodeId: nodeId ?? UUID(),
                highestZIndex: self.visibleGraph.highestZIndex,
                choice: choice,
                center: nodeCenter) else {
            log("nodeCreated: could not create node for \(choice)")
            fatalErrorIfDebug()
            return nil
        }

        self.nodeCreated(node: node)
        return node
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
    

    @MainActor
    func nodeCreated(node: NodeViewModel) {

        // Note: DO NOT RESET THE ACTIVE NODE MENU SELECTION UNTIL ANIMATION HAS COMPLETED
        // Reset selection for insert node menu
        // self.graphUI.insertNodeMenuState.activeSelection = InsertNodeMenuState.allSearchOptions.first

        node.getAllCanvasObservers().forEach {
            $0.parentGroupNodeId = self.groupNodeFocused?.groupNodeId
        }
        self.visibleGraph.visibleNodesViewModel.nodes.updateValue(node, forKey: node.id)
        
        node.initializeDelegate(graph: self.visibleGraph,
                                document: self)
        
        self.visibleGraph.calculateFullGraph()

        // Reset doubleTapLocation
        // TODO: where else would we need to reset this?

        // Do this once the node-insert animation has finished
        //    self.graphUI.doubleTapLocation = nil

        self.graphMovement.draggedCanvasItem = nil
        
        // Reset nodes layout cache
        self.visibleGraph.visibleNodesViewModel.resetCache()
    }
    
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
            log("createNode: unexpectedly had Group node for NodeKind choice; exiting early")
            fatalErrorIfDebug()
            return nil

        // TODO: break this logic up into smaller, separate functions,
        // creating a layer node vs creating a patch node.
        case let .layer(x):
            // just add directly to end of layer nodes list (ordered-dict)
            guard let layerNode = x.defaultNode(
                    id: newNodeId,
                    position: center.toCGSize,
                    zIndex: highestZIndex + 1,
                    graphDelegate: self.visibleGraph) else {
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
            
            var newSidebarData = self.visibleGraph.layersSidebarViewModel.createdOrderedEncodedData()
            newSidebarData.insert(sidebarLayerData, at: 0)
            self.visibleGraph.layersSidebarViewModel.update(from: newSidebarData)
            
            // Focus this, and only this, layer node in inspector
            self.visibleGraph.layersSidebarViewModel.resetEditModeSelections()
            self.visibleGraph.layersSidebarViewModel.sidebarItemSelectedViaEditMode(sidebarLayerData.id)
            self.visibleGraph.layersSidebarViewModel.selectionState.lastFocused = sidebarLayerData.id
            self.visibleGraph.deselectAllCanvasItems()
            
            return layerNode

        case let .patch(x):

            return x.defaultNode(
                id: newNodeId,
                position: center.toCGSize,
                zIndex: highestZIndex + 1,
                graphTime: graphTime,
                graphDelegate: self.visibleGraph)
        }
    }
}

extension GraphState {
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
