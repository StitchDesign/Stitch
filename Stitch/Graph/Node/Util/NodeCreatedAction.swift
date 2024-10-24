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
    @MainActor
    var newNodeCenterLocation: CGPoint {
        // `state.graphUI.center` is always proper center
        self.adjustedDoubleTapLocation(self.localPosition) ?? self.graphUI.center(self.localPosition)
    }
    
    @MainActor
    var newLayerPropertyLocation: CGPoint {
        // `state.graphUI.center` is always proper center
        var center = self.adjustedDoubleTapLocation(self.localPosition) ?? self.graphUI.center(self.localPosition)
        
        center.x -= LayerInspectorView.LAYER_INSPECTOR_WIDTH
        
        return center
    }

    // Used by InsertNodeMenu
    @MainActor
    func nodeCreated(choice: NodeKind, center: CGPoint? = nil) -> NodeViewModel? {
        let nodeCenter = center ?? self.newNodeCenterLocation

        guard let node = self.createNode(
                graphTime: self.graphStepManager.graphStepState.graphTime,
                newNodeId: UUID(),
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

    @MainActor
    func nodeCreated(node: NodeViewModel) {

        let choice = node.kind
        var undoEvents = Actions()
        let nodeId = node.id

        // Note: DO NOT RESET THE ACTIVE NODE MENU SELECTION UNTIL ANIMATION HAS COMPLETED
        // Reset selection for insert node menu
        // self.graphUI.insertNodeMenuState.activeSelection = InsertNodeMenuState.allSearchOptions.first

        node.getAllCanvasObservers().forEach {
            $0.parentGroupNodeId = self.graphUI.groupNodeFocused?.groupNodeId
        }
        self.visibleGraph.visibleNodesViewModel.nodes.updateValue(node, forKey: node.id)
        
        if node.kind.isLayer {
            log("had layer")
            // Note: do not update sidebar-list-state until after the layer node has actually been added to GraphState
            
            // If we created a layer group, it will start out expanded
            if case .layer(.group) = choice {
                log("had layer group, will add to expanded")
                node.layerNode?.isExpandedInSidebar = true
            }
            
            self.visibleGraph.sidebarListState = getMasterListFrom(
                layerNodes: self.visibleGraph.visibleNodesViewModel.layerNodes,
                expanded: self.visibleGraph.getSidebarExpandedItems(),
                orderedSidebarItems: self.visibleGraph.orderedSidebarLayers)
            
            // TODO: why is this necessary?
            _updateStateAfterListChange(
                updatedList: self.visibleGraph.sidebarListState,
                expanded: self.visibleGraph.getSidebarExpandedItems(),
                graphState: self.visibleGraph)
        }
        
        node.initializeDelegate(graph: self.visibleGraph,
                                document: self)
        
        self.visibleGraph.calculateFullGraph()

        // Reset doubleTapLocation
        // TODO: where else would we need to reset this?

        // Do this once the node-insert animation has finished
        //    self.graphUI.doubleTapLocation = nil

        self.graphMovement.draggedCanvasItem = nil
    }

    // GOOD EXAMPLE FOR ARKIT NODES
    @MainActor
    func createDeviceMotionNode(newNodeId: NodeId? = nil,
                                center: CGSize) -> PatchNode {

        let newNodeId: NodeId = newNodeId ?? NodeId()

        let node = deviceMotionNode(id: newNodeId,
                                    position: center,
                                    zIndex: self.visibleGraph.highestZIndex + 1)

        self.visibleGraph.updatePatchNode(node)

        // device motion requires a special item in state
        self.visibleGraph.motionManagers.updateValue(
            createActiveCMMotionManager(),
            forKey: newNodeId)

        return node
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
            #if DEBUG
            fatalError()
            #endif
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
                #if DEBUG
                fatalError()
                #endif
                return nil
            }

            let sidebarLayerData = SidebarLayerData(id: layerNode.id)
            self.visibleGraph.orderedSidebarLayers.insert(sidebarLayerData, at: 0)
            
            return layerNode

        case let .patch(x):

            switch x {
            case .deviceMotion:
                return self.createDeviceMotionNode(
                    newNodeId: newNodeId,
                    center: center.toCGSize)

            default:
                return x.defaultNode(
                    id: newNodeId,
                    position: center.toCGSize,
                    zIndex: highestZIndex + 1,
                    graphTime: graphTime,
                    graphDelegate: self.visibleGraph)
            } // choice
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
