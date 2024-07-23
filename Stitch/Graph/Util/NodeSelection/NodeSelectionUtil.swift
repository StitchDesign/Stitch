//
//  NodeActions.swift
//  prototype
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

struct ToggleSelectAllGraphItems: GraphEvent {
    func handle(state: GraphState) {
        selectAllNodesAtTraversalLevel(state)

        state.selectAllCommentsAtTraversalLevel()
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
        .getVisibleNodes(at: state.graphUI.groupNodeFocused?.asNodeId)

    state.resetSelectedCanvasItems()
    
    visibleNodes.forEach {
        $0.select()
    }
}

// fka `DetermineSelectedNodes`
struct DetermineSelectedCanvasItems: GraphEvent {
    let selectionBounds: CGRect

    func handle(state: GraphState) {
        state.processCanvasSelectionBoxChange(
            cursorSelectionBox: selectionBounds)
    }
}

// TODO: needs to potentially select comment boxes as well
extension GraphState {
    @MainActor
    // fka `processNodeSelectionBoxChange`
    func processCanvasSelectionBoxChange(cursorSelectionBox: CGRect) {
        let graphState = self

        guard cursorSelectionBox.size != .zero else {
            #if DEV_DEBUG
            log("processNodeSelectionBoxChange error: expansion box was size zero")
            #endif
            return
        }

        var smallestDistance: CGFloat?

        let allCanvasItems = self.visibleNodesViewModel.getVisibleCanvasItems(at: self.groupNodeFocused)
        
        for canvasItem in allCanvasItems {
            
            let doesSelectionIntersectCanvasItem = cursorSelectionBox.intersects(canvasItem.bounds.graphBaseViewBounds)
            
            // Selected
            if doesSelectionIntersectCanvasItem {
                
                // Add to selected canvas items
                canvasItem.select()
                
                let thisDistance = CGPointDistanceSquared(
                    from: canvasItem.bounds.graphBaseViewBounds.origin,
                    to: graphState.graphUI.selection.expansionBox.endPoint)

                if !smallestDistance.isDefined {
                    smallestDistance = thisDistance
                }
            } // if intersecrts

            // De-selected
            else {
                // Remove from selected canvas items
                canvasItem.deselect()
            }
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
}
