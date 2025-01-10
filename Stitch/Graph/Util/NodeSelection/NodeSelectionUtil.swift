//
//  NodeActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/30/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreMotion

/*
 TODO: the terminology here is a little confusing, seems opposite in fact?

 e.g. you use this in media-file drop to convert from (1) a CGPoint that is unaware of graph offset and scale into (2) a CGPoint that has taken graph offset and scale into account.

 Useful for positioning a node, when the incoming CGPoint is from a coordinate space that does not have graph offset and scale applied to it.
 */
/// Factor out graph-offset and graph-scale from a location.
func factorOutGraphOffsetAndScale(location: CGPoint,
                                  graphOffset: CGPoint,
                                  graphScale: Double,
                                  deviceScreen: CGRect) -> CGPoint {

    let scaledScreen = deviceScreen.scaleBy(1/graphScale)

    let adjustment = CGPoint(
        x: -(graphOffset.x - deviceScreen.midX + scaledScreen.width/2),
        y: -(graphOffset.y - deviceScreen.midY + scaledScreen.height/2))

    let adjustedLocation: CGPoint = updatePosition(
        position: location.scaleBy(1/graphScale),
        offset: adjustment)

    return adjustedLocation
}

// The CGRect(origin, size) of a node,
// adjusted for graph offset and scale (ie NodsView's .offset and .scaleEffect)
// and device screen size;
// i.e. "how it looks to user on screen", like GeometryReader.

/// Apply graph-offset and graph-scale to a CGRect
/// e.g. a node's NodeSchema.position and .size are ignorant of the .scaleEffect(graphZoom) and .offset(graphOffset) modifiers applied above them.
func applyGraphOffsetAndScale(nodeSize: CGSize,
                              nodePosition: CGPoint,
                              graphOffset: CGPoint,
                              graphScale: Double,
                              deviceScreen: CGRect) -> CGRect {

    //    log("applyGraphOffsetAndScale: deviceScreen: \(deviceScreen)")
    //    log("applyGraphOffsetAndScale: graphOffset: \(graphOffset)")

    let scaledScreen = deviceScreen.scaleBy(graphScale)
    let scaledGraphOffset = graphOffset.scaleBy(graphScale)

    //    log("applyGraphOffsetAndScale: scaledScreen: \(scaledScreen)")
    //    log("applyGraphOffsetAndScale: scaledGraphOffset: \(scaledGraphOffset)")

    let adjustment = CGPoint(
        x: scaledGraphOffset.x + deviceScreen.midX - scaledScreen.width/2,
        y: scaledGraphOffset.y + deviceScreen.midY - scaledScreen.height/2)

    //    log("applyGraphOffsetAndScale: adjustment: \(adjustment)")

    let scaledNodePosition = nodePosition.scaleBy(graphScale)
    //    log("applyGraphOffsetAndScale: scaledNodePosition: \(nodePosition.scaleBy(graphScale))")

    // node's position is within graph's offset and zoom effect;
    // so those must be factored out
    let nodeFinalPosition: CGPoint = updatePosition(
        position: scaledNodePosition,
        offset: adjustment)

    //    log("applyGraphOffsetAndScale: nodeFinalPosition: \(nodeFinalPosition)")

    let scaledNodeSize = nodeSize.scaleBy(graphScale)
    //    log("applyGraphOffsetAndScale: scaledNodeSize: \(scaledNodeSize)")

    let adjustedPosition = CGRect(
        origin: nodeFinalPosition,
        size: scaledNodeSize)

    //    log("applyGraphOffsetAndScale: adjustedPosition: \(adjustedPosition)")

    return adjustedPosition
}

struct SelectAllShortcutKeyPressed: GraphEvent {
    func handle(state: GraphState) {
        
        // If we have at least one actively selected sidebar layers,
        // then select all layers, not canvas items.
        if state.graphUI.isSidebarFocused {            
            let allLayers = state.orderedSidebarLayers.flattenedItems.map(\.id).toSet
            state.sidebarSelectionState.primary = state.sidebarSelectionState.primary.union(allLayers)
            
            state.layersSidebarViewModel.editModeSelectTappedItems(tappedItems: state.sidebarSelectionState.all)
            
        } else {
            selectAllNodesAtTraversalLevel(state)
            state.selectAllCommentsAtTraversalLevel()
        }
    }
}

extension GraphState {
    // TODO: handle proper traversal level comments
    @MainActor
    func selectAllCommentsAtTraversalLevel() {
        self.graphUI.selection.selectedCommentBoxes = self.commentBoxesDict.keys.toSet
    }
}

@MainActor
func selectAllNodesAtTraversalLevel(_ state: GraphState) {
    // Only select the visible nodes,
    // i.e. those at this traversal level.
    let visibleNodes = state.visibleNodesViewModel
        .getVisibleCanvasItems(at: state.graphUI.groupNodeFocused?.asNodeId)

    state.resetSelectedCanvasItems()
    
    visibleNodes.forEach {
        $0.select()
    }
}

// TODO: needs to potentially select comment boxes as well
extension GraphState {
    @MainActor
    // fka `processNodeSelectionBoxChange`
    func processCanvasSelectionBoxChange(selectionBox: CGRect) {
        let graphState = self
        var selectedNodes = Set<CanvasItemId>()
        let nodesSelectedOnShift = self.graphUI.nodesAlreadySelectedAtStartOfShiftNodeCursorBoxDrag
        let isCurrentlyDragging = selectionBox != .zero
        
        // Unfocus sidebar
        graphState.graphUI.isSidebarFocused = false
        
        // TODO: pass shift down via the UIKit gesture handler
        let shiftHeld = graphState.keypressState.shiftHeldDuringGesture
        
        guard isCurrentlyDragging else {
            // log("processNodeSelectionBoxChange error: expansion box was size zero")
            return
        }
        
        if shiftHeld {
            let initiallySelectedNodes = self.selectedCanvasItems.map(\.id).toSet
            let previouslySelectedNodes = self.graphUI.nodesAlreadySelectedAtStartOfShiftNodeCursorBoxDrag ?? .init()

            if self.graphUI.nodesAlreadySelectedAtStartOfShiftNodeCursorBoxDrag == nil {
                // Increment previously-selected shift-click nodes to current selected set
                // on new shift click
                let allSelectedNodes = initiallySelectedNodes.union(previouslySelectedNodes)
                self.graphUI.nodesAlreadySelectedAtStartOfShiftNodeCursorBoxDrag = initiallySelectedNodes.union(allSelectedNodes)
                selectedNodes = selectedNodes.union(allSelectedNodes)
            } else {
                // Ignore previously selected nodes on pre-existing shift click
                selectedNodes = selectedNodes.union(previouslySelectedNodes)
            }
        } else {
            // Note: alternatively?: wipe this collection/set when gesure ends
            self.graphUI.nodesAlreadySelectedAtStartOfShiftNodeCursorBoxDrag = nil
        }
                
        let selectionBoxInViewFrame: CGRect = selectionBox
        
        for cachedSubviewData in self.visibleNodesViewModel.infiniteCanvasCache {
            let id = cachedSubviewData.key
            var cachedBounds = cachedSubviewData.value
            
            guard self.visibleNodesViewModel.visibleCanvasIds.contains(id) else {
                continue
            }
            
            if nodesSelectedOnShift?.contains(id) ?? false {
                continue
            }
            
            // Must offset since location is positioned around center
            let nodeSize = cachedBounds.size
            let positionOffset = CGPoint(x: nodeSize.width / 2,
                                         y: nodeSize.height / 2)
            cachedBounds.origin -= positionOffset
                        
            if selectionBoxInViewFrame.intersects(cachedBounds) {
                selectedNodes.insert(id)
            }
        }
        
        if self.graphUI.selection.selectedNodeIds != selectedNodes {
            self.graphUI.selection.selectedNodeIds = selectedNodes
        }        
        
        // Determine selected comment boxes

//      // TODO: only look at boxes on this traversal level
        // TODO: update comment boxes to use `CanvasItemViewModel`
//        for box in graphState.commentBoxesDict.toValuesArray {
//            if let boxBounds = graphState.graphUI.commentBoxBoundsDict.get(box.id) {
//
//                // node cursor box only selects a comment box if we touch the comment box's title area
//                //                let doesIntersectSelectionBox = nodeCursorSelectionBox.intersects(boxBounds)
//                let doesIntersectSelectionBox = cursorSelectionBox.intersects(boxBounds.titleBounds)
//
//                if doesIntersectSelectionBox {
//                    graphState.graphUI.selection.selectedCommentBoxes.insert(box.id)
//                } else {
//                    graphState.graphUI.selection.selectedCommentBoxes.remove(box.id)
//                }
//
//            } else {
//                log("processNodeSelectionBoxChange: could not get bounds for comment box \(box.id)")
//            }
//        }
        
    }
    
    /// Uses graph local offset and scale to get a modified `CGRect` of the selection box view frame.
}
