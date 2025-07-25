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


struct NodeCreatedWhileInputSelected: StitchDocumentEvent {
    
    // Determined by the shortcut or key that was pressed while the input was selected
    let patch: Patch
    
    func handle(state: StitchDocumentViewModel) {
        state.nodeCreatedWhileInputSelected(patch: patch)
    }
}

extension StitchDocumentViewModel {
    
    // TODO: this can actually only ever be for creating a PatchNode ?
    @MainActor
    func nodeCreatedWhileInputSelected(patch: Patch) {
        let state = self
        let graph = state.visibleGraph

        // A Wireless Broadcaster has no (visible) outgoing edges,
        // so we insert a Wireless Receiver instead.
        // If we attempt to insert
        var patch = patch
        if patch == .wirelessBroadcaster {
            patch = .wirelessReceiver
        }
        
        // Find the input
        guard let selectedInput = state.reduxFocusedField?.inputPortSelected,
              let canvasId = selectedInput.graphItemType.getCanvasItemId,
              var selectedInputLocation = graph.getCanvasItem(canvasId)?.locationOfInputs,
              let selectedInputObserver = state.visibleGraph.getInputRowViewModel(for: selectedInput)?.rowDelegate,
              let selectedInputType: UserVisibleType = selectedInputObserver.values.first?.toNodeType else {
            fatalErrorIfDebug()
            return
        }
        
        // Insert the created node further to the east
        selectedInputLocation.x -= (NODE_POSITION_STAGGER_SIZE * 6)
                
        // Create the node that corresponds to the shortcut/key pressed
        let node = state.nodeInserted(
            choice: .patch(patch),
            canvasLocation: selectedInputLocation)
                
        // Update the created-node's type if node supports the selected input's type
        if patch.availableNodeTypes.contains(selectedInputType) {
            let _ = graph.nodeTypeChanged(nodeId: node.id,
                                          newNodeType: selectedInputType,
                                          activeIndex: state.activeIndex,
                                          graphTime: self.graphStepState.graphTime)
        }
        
        // TODO: use Patch's .graphNode method; right now, however, NodeKind.rowDefinitions properly retrieves row definitions whether new or old style
        let indexOfInputToChange = node.kind.patchOrLayer?.rowDefinitionsOldOrNewStyle(for: selectedInputType).inputs
         // patch.graphNode?.rowDefinitions(for: selectedInputType).inputs
            .firstIndex(where: { !$0.isTypeStatic })
        // Else default to first input
        ?? 0
        
        // Put the selected input's values into the created-node's first non-type-static-input
        
        // NOTE: all shortcut/key-insertable nodes should have NodeDefinitions now
        // TODO: write a test for this ?
        guard let inputOnCreatedNode: InputNodeRowObserver = node.inputsObservers[safe: indexOfInputToChange] else {
            fatalErrorIfDebug()
            return
        }
        
        inputOnCreatedNode.setValuesInInput(selectedInputObserver.values)
        
        guard let firstOutput = node.outputsObservers.first else {
            fatalErrorIfDebug("NodeCreatedWhileInputSelected for \(patch): did not have output") // should never be called for
            return
        }
        
        // Create an edge from the node's output to the selected input
        graph.addEdgeWithoutGraphRecalc(from: firstOutput.id,
                                        to: selectedInputObserver.id)
        
        self.visibleGraph.updateGraphData(self)
        
        // TODO: calculate a smaller portion of the graph?
        graph.calculateFullGraph()
        
        graph.persistNewNode(node)
    }
}

struct NodeCreatedEvent: StitchDocumentEvent {
    
    let choice: PatchOrLayer
    
    func handle(state: StitchDocumentViewModel) {
        let node = state.nodeInserted(choice: choice)
        state.visibleGraph.persistNewNode(node)
    }
}

extension StitchDocumentViewModel {
    
    @MainActor
    func handleNodeCreatedViaShortcut(choice: PatchOrLayer) {
        let node = self.nodeInserted(choice: choice)
        self.visibleGraph.persistNewNode(node)
    }
    
    /// Only for insert-node-menu creation of nodes; shortcut key creation of nodes uses `viewPortCenter`
    @MainActor
    var newCanvasItemInsertionLocation: CGPoint {
        if let doubleTapLocation = self.doubleTapLocation {
            // log("newNodeCenterLocation: had doubleTapLocation: \(doubleTapLocation)")
            return adjustPositionToMultipleOf(doubleTapLocation)
        } else {
            var center = self.viewPortCenter
            center.x -= self.adjustmentFromOpenLayerInspector
            return center
        }
    }
    
    @MainActor
    var adjustmentFromOpenLayerInspector: CGFloat {
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
    func nodeInserted(choice: PatchOrLayer,
                      // For LLMStep Actions
                      nodeId: UUID? = nil,
                      canvasLocation: CGPoint? = nil) -> NodeViewModel {

        let nodeCenter = canvasLocation ?? self.newCanvasItemInsertionLocation
        
        let node = self.visibleGraph.createNode(
                graphTime: self.graphStepManager.graphStepState.graphTime,
                newNodeId: nodeId ?? UUID(),
                highestZIndex: self.visibleGraph.highestZIndex,
                choice: choice,
                center: nodeCenter)

        self.handleNewlyCreatedNode(node: node)
        return node
    }
   
    // Used by insert-node-menu and sidebar-group-creation
    @MainActor
    func handleNewlyCreatedNode(node: NodeViewModel) {
        let graph = self.visibleGraph

        // Note: DO NOT RESET THE ACTIVE NODE MENU SELECTION UNTIL ANIMATION HAS COMPLETED
        // Reset selection for insert node menu
        // self.insertNodeMenuState.activeSelection = InsertNodeMenuState.allSearchOptions.first

        node.getAllCanvasObservers().forEach {
            $0.parentGroupNodeId = self.groupNodeFocused?.groupNodeId
        }
        graph.visibleNodesViewModel.nodes.updateValue(node, forKey: node.id)
        
        // TODO: if we calculate the graph BEFORE we "initialize the delegate", would graph eval "fail"?
        node.initializeDelegate(graph: self.visibleGraph,
                                document: self)
        
        // Update sidebar data after node has been added to state
        // EXCEPT for group layer nodes, which update sidebar with different logic
        if let layerNode = node.layerNode,
           layerNode.layer != .group {
            let isFirstLayer = graph.layersSidebarViewModel.items.isEmpty
            let isDisplayingAiPreviewer = self.storeDelegate?.isShowingAIPreviewer ?? false
            
            // Open sidebars if first created layer
            // and not an AI request
            // and not in AI table reading mode
            if isFirstLayer && !self.isLoadingAI && !isDisplayingAiPreviewer {
                self.leftSidebarOpen = true
                self.storeDelegate?.showsLayerInspector = true
            }
            
            graph.updateLayerSidebar(with: layerNode)
        }
        
        graph.calculateFullGraph()
        
        // Reset nodes layout cache
        graph.visibleNodesViewModel.resetVisibleCanvasItemsCache()
        
        // Reset doubleTapLocation
        // TODO: where else would we need to reset this?

        // Do this once the node-insert animation has finished
        //    self.doubleTapLocation = nil

        self.graphMovement.draggedCanvasItem = nil
    }
    
}

extension GraphState {
    @MainActor
    func updateLayerSidebar(with newLayerNode: LayerNodeViewModel) {
        // Update sidebar data
        var sidebarLayerData = SidebarLayerData(id: newLayerNode.id)
        
        // Creates group node data for reality node
        if newLayerNode.isGroupLayer {
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
    }

    @MainActor
    func createNode(graphTime: TimeInterval,
                    newNodeId: NodeId = NodeId(),
                    highestZIndex: ZIndex,
                    choice: PatchOrLayer,
                    center: CGPoint) -> NodeViewModel {
        //    log("createNode called")

        // increment the "highest z-index", and then use that for next node
        switch choice {

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
                                 center: CGPoint) -> NodeViewModel {
        // just add directly to end of layer nodes list (ordered-dict)
        let layerNode = layer.defaultNode(
                id: newNodeId,
                position: center.toCGSize,
                zIndex: highestZIndex + 1,
                graphDelegate: self)
        
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
