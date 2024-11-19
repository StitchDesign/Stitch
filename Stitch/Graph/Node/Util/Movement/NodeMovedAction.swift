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
        
        // updates port locations for edges
        self.updatePortLocations()
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
struct NodeDuplicateDraggedAction: GraphEvent {
    let id: NodeId
    let translation: CGSize
    
    func handle(state: GraphState) {
        state.nodeDuplicateDragged(id: id,
                                   translation: translation)
    }
}

extension GraphState {
    @MainActor
    func nodeDuplicateDragged(id: NodeId,
                              translation: CGSize) {
        let state = self
        
        guard state.graphUI.dragDuplication else {
            
            // Might need to adjust the currently selected nodes, if e.g. we're option-dragging a node that wasn't previously selected
            guard let canvasItem = state.getCanvasItem(.node(id)) else {
                // log("NodeDuplicateDraggedAction: could not find canvas item for id \(id)")
                return
            }
            
            // If we drag a canvas item that is not yet selected, we'll select it and deselect all the others.
            if !canvasItem.isSelected {
                // log("NodeDuplicateDraggedAction: \(canvasItem.id) was NOT already selected")
                // select the canvas item and de-select all the others
                state.selectSingleCanvasItem(canvasItem)
                // add node's edges to highlighted edges; wipe old highlighted edges
                state.selectedEdges = .init()
            }
            state.graphUI.dragDuplication = true
            
            // Copy nodes if no drag started yet
            let copiedComponentResult = self
                .createCopiedComponent(groupNodeFocused: self.graphUI.groupNodeFocused,
                                       selectedNodeIds: state.selectedNodeIds.compactMap(\.nodeCase).toSet)
            
            let (newComponent, nodeIdMap) = Self.updateCopiedNodes(
                component: copiedComponentResult.component,
                destinationGraphInfo: nil)
            
            // Update top-level nodes to match current focused group
            let newNodes: [NodeEntity] = self.createNewNodes(from: newComponent)
            
            // this actually adds the new components' nodes to the state
            let graph = self.addComponentToGraph(newComponent: newComponent,
                                                 newNodes: newNodes,
                                                 nodeIdMap: nodeIdMap)
            
            self.updateSync(from: graph)
            
            self.updateGraphAfterPaste(newNodes: newNodes)
            
            return
        }
            
        
        // log("NodeDuplicateDraggedAction: state.selectedNodeIds at end: \(state.selectedNodeIds)")
        
        // Drag all selected nodes if dragging already started
        state.selectedNodeIds
            .compactMap { state.getCanvasItem($0) }
            .forEach { draggedNode in
                // log("NodeDuplicateDraggedAction: already had dragged node id, so will do normal node drag for id \(draggedNode.id)")
                state.canvasItemMoved(for: draggedNode,
                                      translation: translation,
                                      wasDrag: true)
            }
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
        

        #if DEV_DEBUG
        log("canvasItemMoved: original id: \(id)")
        #endif

        // Edges should *never* animate when node is being dragged
        self.graphUI.edgeAnimationEnabled = false

        // Dragging node exits edge-edit-mode
        self.graphUI.edgeEditingState = nil

        /*
         HACK:

         We must allow both node TapGesture and node LongPress(minDur=0) to be simultaneousGestures (`highPriorityGesture` and `exclusively(before:)` do not help);
         and regardless of gesture ordering, SwiftUI always detects the long press BEFORE the tap.

         This means that tapping on a node activates first the long press, then the tap.

         Normally this is fine, except when we hold command:
         long press would fire and see that the node was not yet selected, so it would select it; then tap would fire and see that the node was already selected, so it would de-select that same node.
         */
        // TODO: pass isCommandPressed down from the gesture handler
        if !wasDrag && (self.documentDelegate?.keypressState.isCommandPressed ?? false) {
            #if DEV_DEBUG
            log("canvasItemMoved: we long pressed while holding command; doing nothing; this logic will instead be handled by NodeTapped")
            #endif
            return
        }

        // Exit if another (non-duplicated) node is being dragged
        // Note: do this check AFTER we've set our 'currently dragged id' to be the option-duplicated node's id.
        // TODO: duplicate-node-drag should also update the `draggedNode` in GraphState ?
        // Overall, node duplication logic needs to be thought through with multigestures in mind.
        if let draggedCanvasItem = self.graphMovement.draggedCanvasItem,
           draggedCanvasItem != canvasItem.id {
            #if DEV_DEBUG
            log("canvasItemMoved: some other node is already dragged: \(draggedCanvasItem)")
            #endif
            return
        }

        // Updating for dual-drag; must set before

        self.graphMovement.draggedCanvasItem = canvasItem.id
        self.graphMovement.lastCanvasItemTranslation = translation

        // If we don't have an active first gesture,
        // and graph isn't already dragging,
        // then set node-drag as active first gesture
        if self.graphMovement.firstActive == .none {
            if !self.graphMovement.graphIsDragged {
                // log("canvasItemMoved: will set .node as active first gesture")
                self.graphMovement.firstActive = .node
            }
        }
        if self.graphMovement.firstActive == .graph {

            if !self.graphMovement.runningGraphTranslationBeforeNodeDragged.isDefined {
                #if DEV_DEBUG
                log("canvasItemMoved: setting runningGraphTranslationBeforeNodeDragged to be self.graphMovement.runningGraphTranslation: \(self.graphMovement.runningGraphTranslation)")
                #endif
                self.graphMovement
                    .runningGraphTranslationBeforeNodeDragged = (
                        self.graphMovement.runningGraphTranslation ?? .zero) / self.graphMovement.zoomData.zoom
            }
        }

        // first, determine which nodes are selected;
        // then update positions and selected nodes

        // Dragging an unselected node selects that node
        // and de-selects all other nodes.
        let alreadySelected = canvasItem.isSelected

        if !alreadySelected {
            // update node's position
            self.updateCanvasItemOnDragged(canvasItem, translation: translation)

            // select the canvas item and de-select all the others
            self.selectSingleCanvasItem(canvasItem)

            // add node's edges to highlighted edges; wipe old highlighted edges
            self.selectedEdges = .init()
        }

        // If we're dragging a node that's already selected,
        // then just update positions of all selected nodes.
        else {
            self.selectedCanvasItems
            // need to sort by z index to retain order
                .sorted { $0.zIndex < $1.zIndex }
                .forEach { self.updateCanvasItemOnDragged($0, translation: translation) }
        }

        // end any edge-drawing
        self.edgeDrawingObserver.reset()
        self.nodeIsMoving = true
        self.outputDragStartedCount = 0
    }
}

// Drag.onEnded
struct NodeMoveEndedAction: StitchDocumentEvent {
//    let id: NodeId // id of node or rectangle
    let id: CanvasItemId // id of node or rectangle

    func handle(state: StitchDocumentViewModel) {
        state.handleNodeMoveEnded(id: id)
        state.visibleGraph.encodeProjectInBackground()
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
            
            let nodeSize = canvasItem.graphBaseViewSize
            
            canvasItem.position = determineSnapPosition(
                position: canvasItem.position,
                previousPosition: canvasItem.previousPosition,
                nodeSize: nodeSize)
            
            let positionAtStart = canvasItem.previousPosition
            canvasItem.previousPosition = canvasItem.position
            
            // Refresh ports
            canvasItem.updatePortLocations()
            
            let diff = canvasItem.position - positionAtStart
//            self.maybeCreateLLMMoveNode(canvasItem: canvasItem,
//                                        diff: diff)
        }
        
        // Update boundary nodes
        
        self.visibleGraph.selectedCanvasItems.forEach { _update($0) }
        
        self.visibleGraph.nodeIsMoving = false
        self.visibleGraph.outputDragStartedCount = 0
        
        // reset
        self.graphUI.dragDuplication = false
        
        // Rebuild comment boxes
        self.visibleGraph.rebuildCommentBoxes()
        
        // Recalculate positional data
        self.updateBoundaryNodes()
    }
    
    @MainActor
    func updateBoundaryNodes() {
        let visibleGraph = self.visibleGraph
        let groupNodeFocused = visibleGraph.groupNodeFocused
        
        // NOTE: nodes are retrieved per active traversal level,
        // ie top level vs some specific, focused group.
        let canvasItemsAtTraversalLevel = visibleGraph.canvasItemsAtTraversalLevel(groupNodeFocused)
        
        // If there are no nodes, then there is no graphBounds
        guard let east = GraphState.easternMostNode(groupNodeFocused,
                                                    canvasItems: canvasItemsAtTraversalLevel),
              let west = GraphState.westernMostNode(groupNodeFocused,
                                                    canvasItems: canvasItemsAtTraversalLevel),
              let south = GraphState.southernMostNode(groupNodeFocused,
                                                      canvasItems: canvasItemsAtTraversalLevel),
              let north = GraphState.northernMostNode(groupNodeFocused,
                                                      canvasItems: canvasItemsAtTraversalLevel) else {
            //            log("GraphState: graphBounds: had no nodes")
            return
        }
        
        self.graphMovement.boundaryNodes = .init(north: north.position,
                                                 south: south.position,
                                                 west: west.position,
                                                 east: east.position)
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
    func rebuildCommentBoxes() {

        guard !self.commentBoxesDict.isEmpty else {
            log("rebuildCommentBoxes: no comment boxes; returning early")
            return
        }

        let currentTraversalLevel = self.graphUI.groupNodeFocused?.asNodeId

        // Only check nodes on this current traversal level
        let visibleNodes = self.getVisibleCanvasItems()
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
