//
//  NodeMovedAction.swift
//  Stitch
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
        guard let graphMovement = self.documentDelegate?.graphMovement else {
            fatalErrorIfDebug()
            return
        }
        
        canvasItem.updateCanvasItemOnDragged(translation: translation,
                                             highestZIndex: self.highestZIndex + 1,
                                             state: graphMovement)
    }
}

//extension NodeViewModel {
extension CanvasItemViewModel {
    
    // fka `updateNodeOnDragged`
    // UPDATED FOR DUAL DRAG: when node dragged directly
    @MainActor
    func updateCanvasItemOnDragged(translation: CGSize,
                                   highestZIndex: ZIndex?,
                                   state: GraphMovementObserver) {
        
        // let zoom = state.zoomData
        
        // log("updateCanvasItemOnDragged self.position was: \(self.position)")
        // Set z-index once on node movement
        if !self.isMoving,
           let highestZIndex = highestZIndex {
            self.zIndex = highestZIndex
        }

        /*
         
         NOTE: `/ zoom` required when using SwiftUI .global on nodes' DragGesture
                let translationSize = (translation / zoom)
                    - ((state.runningGraphTranslation ?? .zero) / zoom)
         
         However, not required when using UIKit GestureRecognizer.
         */
        let translationSize = translation
            - ((state.runningGraphTranslation ?? .zero))
            + (state.runningGraphTranslationBeforeNodeDragged ?? .zero)
            - state.accumulatedGraphTranslation

        self.position = self.previousPosition + translationSize.toCGPoint
        // log("updateCanvasItemOnDragged self.position is now: \(self.position)")
        
        // updates port locations for edges
        self.updateAnchorPoints()
    }

    // fka `updateNodeOnGraphDragged`
    @MainActor
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

extension GraphState {
    /// Duplicates a node on option + drag before dragging affected canvas items.
    @MainActor
    func nodeDuplicateDragged(id: NodeId,
                              document: StitchDocumentViewModel) {
        let state = self
        
        // Might need to adjust the currently selected nodes, if e.g. we're option-dragging a node that wasn't previously selected
        guard let canvasItem = state.getCanvasItem(.node(id)) else {
            // log("NodeDuplicateDraggedAction: could not find canvas item for id \(id)")
            return
        }
        
        // If we drag a canvas item that is not yet selected, we'll select it and deselect all the others.
        if !state.isCanvasItemSelected(canvasItem.id) {
            // log("NodeDuplicateDraggedAction: \(canvasItem.id) was NOT already selected")
            // select the canvas item and de-select all the others
            state.selectSingleCanvasItem(canvasItem.id)
            // add node's edges to highlighted edges; wipe old highlighted edges
            state.selectedEdges = .init()
        }
                
        // Copy nodes if no drag started yet
        let copyResult = self.createCopiedComponent(
            groupNodeFocused: document.groupNodeFocused,
            selectedNodeIds: state.selectedCanvasItems.compactMap(\.nodeCase).toSet)
                
        let (destinationGraphEntity, newNodes, nodeIdMap) = Self.insertNodesAndSidebarLayersIntoDestinationGraph(
            destinationGraph: self.createSchema(),
            graphToInsert: copyResult.component.graphEntity,
            focusedGroupNode: document.groupNodeFocused?.groupNodeId,
            destinationGraphInfo: nil,
            originalOptionDraggedLayer: nil)
        
        // TODO: should we provide an explicit `rootUrl` here too? See `sidebarSelectedItemsDuplicated`
        self.update(from: destinationGraphEntity)
        
        self.updateGraphAfterPaste(newNodes: newNodes,
                                   nodeIdMap: nodeIdMap,
                                   isOptionDragInSidebar: false)
    }
}

// Drag.onChanged
extension GraphState {
    @MainActor
    // fka `nodeMoved`
    func canvasItemMoved(translation: CGSize,
                         // drag vs long-press
                         wasDrag: Bool,
                         document: StitchDocumentViewModel) {
        
        // log("canvasItemMoved: original id: \(id)")

        // Edges should *never* animate when node is being dragged
        self.edgeAnimationEnabled = false

        // Dragging node exits edge-edit-mode
        self.edgeEditingState = nil

        /*
         HACK:

         We must allow both node TapGesture and node LongPress(minDur=0) to be simultaneousGestures (`highPriorityGesture` and `exclusively(before:)` do not help);
         and regardless of gesture ordering, SwiftUI always detects the long press BEFORE the tap.

         This means that tapping on a node activates first the long press, then the tap.

         Normally this is fine, except when we hold command:
         long press would fire and see that the node was not yet selected, so it would select it; then tap would fire and see that the node was already selected, so it would de-select that same node.
         */
        // TODO: pass isCommandPressed down from the gesture handler
        if !wasDrag && (document.keypressState.isCommandPressed) {
            log("canvasItemMoved: we long pressed while holding command; doing nothing; this logic will instead be handled by NodeTapped")
            return
        }

        guard let graphMovement = self.documentDelegate?.graphMovement else {
            fatalErrorIfDebug()
            return
        }
        
        graphMovement.lastCanvasItemTranslation = translation

        if graphMovement.firstActive == .graph {

            if !graphMovement.runningGraphTranslationBeforeNodeDragged.isDefined {
                log("canvasItemMoved: setting runningGraphTranslationBeforeNodeDragged to be graphMovement.runningGraphTranslation: \(String(describing: graphMovement.runningGraphTranslation))")
                graphMovement
                    .runningGraphTranslationBeforeNodeDragged = (
                        graphMovement.runningGraphTranslation ?? .zero) / graphMovement.zoomData
            }
        }

        // update positions of all selected nodes.
        self.getSelectedCanvasItems(groupNodeFocused: document.groupNodeFocused?.groupNodeId)
        // need to sort by z index to retain order
            .sorted { $0.zIndex < $1.zIndex }
            .forEach { self.updateCanvasItemOnDragged($0, translation: translation) }

        // end any edge-drawing
        self.edgeDrawingObserver.reset()
        self.nodeIsMoving = true
    }
}

// Drag.onEnded
struct NodeMoveEndedAction: StitchDocumentEvent {
    let id: CanvasItemId // id of node or rectangle

    func handle(state: StitchDocumentViewModel) {
        state.handleNodeMoveEnded(id: id)
        state.visibleGraph.encodeProjectInBackground()
        
        // Reset node positions cache
        if !state.visibleGraph.visibleNodesViewModel.needsInfiniteCanvasCacheReset {
            state.visibleGraph.visibleNodesViewModel.needsInfiniteCanvasCacheReset = true
        }
    }
}

extension StitchDocumentViewModel {
    // `handleNodeMoveEnded`
    // mutates GraphState, but also has to update GraphSchema
    @MainActor
    func handleNodeMoveEnded(id: CanvasItemId) {
        
#if DEV_DEBUG
        log("handleNodeMoveEnded: id \(id): ")
#endif
        
        let groupNodeFocused = self.groupNodeFocused?.groupNodeId
        let graph = self.visibleGraph
        
        // DUAL DRAG:
        self.graphMovement.stopNodeMovement()
        
        if self.graphMovement.graphIsDragged {
            log("handleNodeMoveEnded: will set .graph as active first gesture")
            self.graphMovement.firstActive = .graph
        } else {
            log("handleNodeMoveEnded: will set .none as active first gesture")
            self.graphMovement.firstActive = .none
        }
        
        let _update = { (canvasItem: CanvasItemViewModel) in
            
            guard let nodeSize = canvasItem.graphBaseViewSize(self.graphMovement) else {
                return
            }
            
            canvasItem.position = determineSnapPosition(
                position: canvasItem.position,
                previousPosition: canvasItem.previousPosition,
                nodeSize: nodeSize)
            
//            let positionAtStart = canvasItem.previousPosition
            canvasItem.previousPosition = canvasItem.position
            log("handleNodeMoveEnded: canvasItem id \(canvasItem.id) is now at position \(canvasItem.position)")
            
            // Refresh ports
            canvasItem.updateAnchorPoints()
            
//            let diff = canvasItem.position - positionAtStart
//            self.maybeCreateLLMMoveNode(canvasItem: canvasItem,
//                                        diff: diff)
        }
        
        // Update boundary nodes
        
        graph.getSelectedCanvasItems(groupNodeFocused: groupNodeFocused)
            .forEach { _update($0) }
        
        graph.nodeIsMoving = false
        
        // Rebuild comment boxes
        graph.rebuildCommentBoxes(currentTraversalLevel: groupNodeFocused)
    }
}

extension GraphState {
    func buildCommentBoxes(visibleNodes: CanvasItemViewModels,
                           visibleCommentBoxes: [CommentBoxViewModel],
                           commentBoxBoundsDict: CommentBoxBoundsDict) {
        
        fatalErrorIfDebug("Must rebuild with bounds logic changing")

//        for box in visibleCommentBoxes {
//            if let boxBounds = commentBoxBoundsDict.get(box.id) {
//                let nodesInsideCommentBox = visibleNodes
//                    .filter {
//                        // Building a comment box's node-set looks at box's border, not its title
//                        //                    let intersects = boxBounds.intersects($0.bounds)
//                        let intersects = boxBounds.borderBounds.intersects($0.bounds.graphBaseViewBounds)
//
//                        // log("buildCommentBoxes: boxBounds: \(boxBounds)")
//                        // log("buildCommentBoxes: node.bounds: \($0.bounds)")
//
//                        //                    if intersects {
//                        //                        log("buildCommentBoxes: node \($0.id) intersects comment box \(box.id)")
//                        //                    }
//
//                        return intersects
//                    }
//                    .map(\.id)
//                    .toSet
//
//                box.nodes = nodesInsideCommentBox
//            }
//            //        else {
//            //            log("buildCommentBoxes: could not find bounds for comment box \(box.id)")
//            //        }
//        } // for box in ...
    }

    // Reads but does not mutate GraphState
    @MainActor
    func rebuildCommentBoxes(currentTraversalLevel: NodeId?) {

        guard !self.commentBoxesDict.isEmpty else {
            // log("rebuildCommentBoxes: no comment boxes; returning early")
            return
        }

        // Only check nodes on this current traversal level
        let visibleNodes = self.getCanvasItemsAtTraversalLevel(groupNodeFocused: currentTraversalLevel)
        let visibleCommentBoxes = self
            .commentBoxesDict.boxesForTraversalLevel(currentTraversalLevel)

        // Only check comment-boxes on this current traversal level
        guard !visibleCommentBoxes.isEmpty else {
            // log("rebuildCommentBoxes: no comment boxes for this traversal level")
            return
        }

        return self.buildCommentBoxes(visibleNodes: visibleNodes,
                                      visibleCommentBoxes: visibleCommentBoxes,
                                      commentBoxBoundsDict: self.commentBoxBoundsDict)

    } // func

}
