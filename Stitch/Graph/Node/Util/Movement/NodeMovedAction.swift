//
//  NodeMovedAction.swift
//  prototype
//
//  Created by Christian J Clampitt on 8/5/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
    
    // fka `updateNodeOnDragged`
    @MainActor
    func updateCanvasItemOnDragged(_ canvasItem: CanvasItemViewModel,
                                   translation: CGSize) {
        canvasItem.updateCanvasItemOnDragged(translation: translation,
                                             highestZIndex: self.highestZIndex + 1,
                                             zoom: self.graphMovement.zoomData.zoom,
                                             state: self.graphMovement)
    }
}

//extension NodeViewModel {
extension CanvasItemViewModel {
    
    // fka `updateNodeOnDragged`
    // UPDATED FOR DUAL DRAG: when node dragged directly
    @MainActor
    func updateCanvasItemOnDragged(translation: CGSize,
                                   highestZIndex: ZIndex?,
                                   zoom: CGFloat,
                                   state: GraphMovementObserver) {
        log("updateCanvasItemOnDragged self.position was: \(self.position)")
        // Set z-index once on node movement
        if !self.isMoving,
           let highestZIndex = highestZIndex {
            self.zIndex = highestZIndex
        }

        let translationSize = (translation / zoom) // required when using SwiftUI .global on nodes' DragGesture
            - ((state.runningGraphTranslation ?? .zero) / zoom)
            + (state.runningGraphTranslationBeforeNodeDragged ?? .zero)
            - state.accumulatedGraphTranslation

        self.position = self.previousPosition + translationSize.toCGPoint
        log("updateCanvasItemOnDragged self.position is now: \(self.position)")
    }

    // fka `updateNodeOnGraphDragged`
    func updateNodeOnGraphDragged(_ translation: CGSize,
                                  _ highestZIndex: ZIndex,
                                  zoom: CGFloat,
                                  state: GraphMovementObserver) {
        self.zIndex = highestZIndex

        let translationSize = state.lastCanvasItemTranslation
            - (translation / zoom)
            - state.accumulatedGraphTranslation
            + (state.runningGraphTranslationBeforeNodeDragged ?? .zero)
        
        self.position = self.previousPosition + translationSize.toCGPoint
    }
}

// ie we dragged the node while holding `Option` key
// TODO: this seems to only duplicate a single node?
// TODO: we can only dupe-drag nodes and comment boxes, NOT layer-inputs-on-graph
// What if we have multiple nodes on the graph selected and we hold `Option` + drag?
struct NodeDuplicateDraggedAction: GraphEventWithResponse {
    let id: NodeId
    let translation: CGSize

    func handle(state: GraphState) -> GraphResponse {
        log("NodeDuplicateDraggedAction called")
        
        guard state.graphUI.dragDuplication else {
            // Copy nodes if no drag started yet
            state.copyAndPasteSelectedNodes()
            state.graphUI.dragDuplication = true
            return .persistenceResponse
        }

        // Drag all selected nodes if dragging already started
        state.selectedNodeIds
            .compactMap { state.getNodeViewModel($0)?.canvasUIData }
            .forEach { draggedNode in
                // log("NodeDuplicateDraggedAction: already had dragged node id, so will do normal node drag")
                state.canvasItemMoved(for: draggedNode,
                                      translation: translation,
                                      wasDrag: true)
            }
        
        return .persistenceResponse
    }
}

// Drag.onChanged
extension GraphState {
    @MainActor
    // fka `nodeMoved`
    func canvasItemMoved(for canvasItem: CanvasItemViewModel,
                         translation: CGSize,
                         // drag vs long-press
                         wasDrag: Bool) {
        
        let graphState = self
        var canvasItemToDrag = canvasItem

        #if DEV_DEBUG
        log("canvasItemMoved: original id: \(id)")
        #endif

        // Edges should *never* animate when node is being dragged
        graphState.graphUI.edgeAnimationEnabled = false

        // Dragging node exits edge-edit-mode
        graphState.graphUI.edgeEditingState = nil

        /*
         HACK:

         We must allow both node TapGesture and node LongPress(minDur=0) to be simultaneousGestures (`highPriorityGesture` and `exclusively(before:)` do not help);
         and regardless of gesture ordering, SwiftUI always detects the long press BEFORE the tap.

         This means that tapping on a node activates first the long press, then the tap.

         Normally this is fine, except when we hold command:
         long press would fire and see that the node was not yet selected, so it would select it; then tap would fire and see that the node was already selected, so it would de-select that same node.
         */
        if !wasDrag && graphState.graphUI.keypressState.isCommandPressed {
            #if DEV_DEBUG
            log("canvasItemMoved: we long pressed while holding command; doing nothing; this logic will instead be handled by NodeTapped")
            #endif
            return
        }

        // Exit if another (non-duplicated) node is being dragged
        // Note: do this check AFTER we've set our 'currently dragged id' to be the option-duplicated node's id.
        // TODO: duplicate-node-drag should also update the `draggedNode` in GraphState ?
        // Overall, node duplication logic needs to be thought through with multigestures in mind.
        if let draggedCanvasItem = graphState.graphMovement.draggedCanvasItem,
           draggedCanvasItem != canvasItemToDrag.id {
            #if DEV_DEBUG
            log("canvasItemMoved: some other node is already dragged: \(draggedCanvasItem)")
            #endif
            return
        }

        // Updating for dual-drag; must set before

        graphState.graphMovement.draggedCanvasItem = canvasItemToDrag.id
        graphState.graphMovement.lastCanvasItemTranslation = translation

        // If we don't have an active first gesture,
        // and graph isn't already dragging,
        // then set node-drag as active first gesture
        if graphState.graphMovement.firstActive == .none {
            if !graphState.graphMovement.graphIsDragged {
                // log("canvasItemMoved: will set .node as active first gesture")
                graphState.graphMovement.firstActive = .node
            }
        }
        if graphState.graphMovement.firstActive == .graph {

            if !graphState.graphMovement.runningGraphTranslationBeforeNodeDragged.isDefined {
                #if DEV_DEBUG
                log("canvasItemMoved: setting runningGraphTranslationBeforeNodeDragged to be graphState.graphMovement.runningGraphTranslation: \(graphState.graphMovement.runningGraphTranslation)")
                #endif
                graphState.graphMovement
                    .runningGraphTranslationBeforeNodeDragged = (
                        graphState.graphMovement.runningGraphTranslation ?? .zero) / graphState.graphMovement.zoomData.zoom
            }
        }

        // first, determine which nodes are selected;
        // then update positions and selected nodes

        // Dragging an unselected node selects that node
        // and de-selects all other nodes.
//        let alreadySelected = graphState.selectedNodeIds.contains(nodeToDrag.id)
        let alreadySelected = canvasItemToDrag.isSelected

        if !alreadySelected {
            // update node's position
            self.updateCanvasItemOnDragged(canvasItem, translation: translation)

            // select the node
//            graphState.selectSingleNode(nodeToDrag)
            canvasItemToDrag.select()

            // add node's edges to highlighted edges; wipe old highlighted edges
            graphState.selectedEdges = .init()
        }

        // If we're dragging a node that's already selected,
        // then just update positions of all selected nodes.
        else {
//            graphState.selectedNodeIds
//                .compactMap { self.getNodeViewModel($0) }
            graphState.selectedCanvasItems
//                .compactMap { self.getCanvasItem($0) }
            // need to sort by z index to retain order
                .sorted { $0.zIndex < $1.zIndex }
                .forEach { self.updateCanvasItemOnDragged($0, translation: translation) }
        }

        // end any edge-drawing
        graphState.edgeDrawingObserver.reset()
        graphState.nodeIsMoving = true
        graphState.outputDragStartedCount = 0
    }
}

// Drag.onEnded
struct NodeMoveEndedAction: GraphEventWithResponse {
//    let id: NodeId // id of node or rectangle
    let id: CanvasItemId // id of node or rectangle

    func handle(state: GraphState) -> GraphResponse {
        state.handleNodeMoveEnded(id: id)
        return .persistenceResponse
    }
}

extension GraphState {
    // mutates GraphState, but also has to update GraphSchema
    @MainActor
    func handleNodeMoveEnded(id: CanvasItemId) {
        
#if DEV_DEBUG
        log("handleNodeMoveEnded: id \(id): ")
#endif
        
        // DUAL DRAG:
        self.graphMovement.stopNodeMovement()
        
        if self.graphMovement.graphIsDragged {
            log("handleNodeMoveEnded: will set .graph as active first gesture")
            self.graphMovement.firstActive = .graph
        } else {
            log("handleNodeMoveEnded: will set .none as active first gesture")
            self.graphMovement.firstActive = .none
        }
        
//        let _update = { (id: CanvasItemId) in
        let _update = { (node: CanvasItemViewModel) in
            
////            guard let node = self.visibleNodesViewModel.getViewModel(id) else {
//            guard let node = self.getCanvasItem(id) else {
//#if DEV_DEBUG
//                log("handleNodeMoveEnded: _update: could not find canvas item \(id)")
//#endif
//                return
//            }
            
            //        let nodeSize = node.geometryObserver.bounds.size
            let nodeSize = node.bounds.graphBaseViewBounds.size
            
            node.position = determineSnapPosition(
                position: node.position,
                previousPosition: node.previousPosition,
                nodeSize: nodeSize)
            
            let positionAtStart = node.previousPosition
            node.previousPosition = node.position
                
            // TODO: support LLM Actions for LayerInputOnGraph
            if let nodeId = id.nodeCase(), let node = self.getNode(nodeId) {
                let diff = node.position - positionAtStart
                self.maybeCreateLLMMoveNode(node: node,
                                            diff: diff)
            }
            
        }
        
    // if node is selected, update
        
        // if we're dragging an already selected canvas item, then update ALL canvas items' positions;
        // else, update only the position of the single
        
        // The initial `canvasItemMoved` should handle which canvas items are selected or
        
        
        self.selectedCanvasItems.forEach { _update($0) }
        
//        
//        guard let node = self.getCanvasItem(id) else {
//            fatalErrorIfDebug()
//            return
//        }
        
//        if node.isSelected {
////            for selectedId in self.selectedNodeIds {
//            for selectedId in self.selectedCanvasItems.map(\.id).toSet {
//                _update(selectedId)
//            }
//        } else {
//            _update(id)
//        }
        
        self.nodeIsMoving = false
        self.outputDragStartedCount = 0
        
        // reset
        self.graphUI.dragDuplication = false
        
        // Rebuild comment boxes
        self.rebuildCommentBoxes()
    }
}

extension GraphState {
    func buildCommentBoxes(visibleNodes: NodeViewModels,
                           visibleCommentBoxes: [CommentBoxViewModel],
                           commentBoxBoundsDict: CommentBoxBoundsDict) {

        for box in visibleCommentBoxes {
            if let boxBounds = commentBoxBoundsDict.get(box.id) {
                let nodesInsideCommentBox: IdSet = visibleNodes
                    .filter {
                        // Building a comment box's node-set looks at box's border, not its title
                        //                    let intersects = boxBounds.intersects($0.bounds)
                        let intersects = boxBounds.borderBounds.intersects($0.bounds.graphBaseViewBounds)

                        // log("buildCommentBoxes: boxBounds: \(boxBounds)")
                        // log("buildCommentBoxes: node.bounds: \($0.bounds)")

                        //                    if intersects {
                        //                        log("buildCommentBoxes: node \($0.id) intersects comment box \(box.id)")
                        //                    }

                        return intersects
                    }
                    .map(\.id)
                    .toSet

                var box = box
                box.nodes = nodesInsideCommentBox
            }
            //        else {
            //            log("buildCommentBoxes: could not find bounds for comment box \(box.id)")
            //        }
        } // for box in ...
    }

    // Reads but does not mutate GraphState
    @MainActor
    func rebuildCommentBoxes() {

        guard !self.commentBoxesDict.isEmpty else {
            log("rebuildCommentBoxes: no comment boxes; returning early")
            return
        }

        let currentTraversalLevel = self.graphUI.groupNodeFocused?.asNodeId

        // Only check nodes on this current traversal level
        let visibleNodes = self.getVisibleNodes()
        let visibleCommentBoxes = self
            .commentBoxesDict.boxesForTraversalLevel(currentTraversalLevel)

        // Only check comment-boxes on this current traversal level
        guard !visibleCommentBoxes.isEmpty else {
            log("rebuildCommentBoxes: no comment boxes for this traversal level")
            return
        }

        return self.buildCommentBoxes(visibleNodes: visibleNodes,
                                      visibleCommentBoxes: visibleCommentBoxes,
                                      commentBoxBoundsDict: self.graphUI.commentBoxBoundsDict)

    } // func

}
