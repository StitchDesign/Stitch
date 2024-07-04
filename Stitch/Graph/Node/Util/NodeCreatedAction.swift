//
//  NodeCreatedAction.swift
//  prototype
//
//  Created by Christian J Clampitt on 8/5/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreMotion

struct NodeCreatedEvent: GraphEventWithResponse {
    
    let choice: NodeKind
    
    func handle(state: GraphState) -> GraphResponse {
        let _ = state.nodeCreated(choice: choice)
        return .shouldPersist
    }
}

extension GraphState {
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
    func nodeCreated(choice: NodeKind) -> NodeId? {
        let center = self.newNodeCenterLocation

        guard let node = self.createNode(
                graphTime: self.graphStepManager.graphStepState.graphTime,
                newNodeId: UUID(),
                highestZIndex: self.highestZIndex,
                choice: choice,
                center: center) else {
            log("nodeCreated: could not create node for \(choice)")
            #if DEBUG || DEV_DEBUG
            fatalError()
            #endif
            return nil
        }

        return self.nodeCreated(node: node)
    }

    @MainActor
    func nodeCreated(node: NodeViewModel) -> NodeId? {

        let choice = node.kind
        var undoEvents = Actions()
        let nodeId = node.id

        // Note: DO NOT RESET THE ACTIVE NODE MENU SELECTION UNTIL ANIMATION HAS COMPLETED
        // Reset selection for insert node menu
        // self.graphUI.insertNodeMenuState.activeSelection = InsertNodeMenuState.allSearchOptions.first

        node.parentGroupNodeId = self.graphUI.groupNodeFocused?.asNodeId
        self.visibleNodesViewModel.nodes.updateValue(node, forKey: node.id)
        
        if node.kind.isLayer {
            log("had layer")
            // Note: do not update sidebar-list-state until after the layer node has actually been added to GraphState
            
            // If we created a layer group, it will start out expanded
            if case .layer(.group) = choice {
                log("had layer group, will add to expanded")
                node.layerNode?.isExpandedInSidebar = true
            }
            
            self.sidebarListState = getMasterListFrom(
                layerNodes: self.visibleNodesViewModel.layerNodes,
                expanded: self.getSidebarExpandedItems(),
                orderedSidebarItems: self.orderedSidebarLayers)
            
            // TODO: why is this necessary?
            _updateStateAfterListChange(
                updatedList: self.sidebarListState,
                expanded: self.getSidebarExpandedItems(),
                graphState: self)
        }

        // Little hack to update node data so first render works proper
        self.update(from: self.createSchema())

        // TODO: handle camera undo event
        // Undo event needed for camera feed to update manager if camera feed addition is undo'd
        if choice == .patch(.cameraFeed) {
            undoEvents.append(CameraFeedNodeDeleted(nodeId: nodeId))
        }

        // Reset doubleTapLocation
        // TODO: where else would we need to reset this?

        // Do this once the node-insert animation has finished
        //    self.graphUI.doubleTapLocation = nil

        self.graphMovement.draggedCanvasItem = nil

        
        return nodeId
    }

    // GOOD EXAMPLE FOR ARKIT NODES
    @MainActor
    func createDeviceMotionNode(newNodeId: NodeId? = nil,
                                center: CGSize) -> PatchNode {

        let newNodeId: NodeId = newNodeId ?? NodeId()

        let node = deviceMotionNode(id: newNodeId,
                                    position: center,
                                    zIndex: self.highestZIndex + 1)

        self.updatePatchNode(node)

        // device motion requires a special item in state
        self.motionManagers.updateValue(
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
                    activeIndex: self.activeIndex,
                    graphDelegate: self) else {
                #if DEBUG
                fatalError()
                #endif
                return nil
            }

            let sidebarLayerData = SidebarLayerData(id: layerNode.id)
            self.orderedSidebarLayers.insert(sidebarLayerData, at: 0)
            
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
                    activeIndex: self.activeIndex,
                    graphDelegate: self)
            } // choice
        }
    }
}
