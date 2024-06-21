//
//  NodeSchemaUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/25/23.
//

import Foundation
import StitchSchemaKit

// When we duplicate a node or comment, how far do we adjust its position?
let GRAPH_ITEM_POSITION_SHIFT_INCREMENT = CGFloat(SQUARE_SIDE_LENGTH) * 2

extension CGPoint {
    mutating func shiftNodePosition() {
        let gridLineLength = GRAPH_ITEM_POSITION_SHIFT_INCREMENT

        self.x += gridLineLength
        self.y += gridLineLength
    }
}

extension NodeViewModel {
    func adjustPosition(center: CGPoint) {
        let nodeSize = self.bounds.graphBaseViewBounds.size

        self.position = gridAlignedPosition(center: center,
                                            nodeSize: nodeSize)
        self.previousPosition = self.position
    }
}

// Note: previously we had a side-effect delay to work around some issues with `.buttonStyle(.plain)`'s auto animation and a GraphSchema-update interrupting double tap. These issues now seem to be resolved.
extension GraphState {
    
    @MainActor
    func canvasItemTapped(_ id: CanvasItemId) {
        log("canvasItemTapped: id: \(id)")
        
        guard let canvasItem = self.getCanvasItem(id) else {
            fatalErrorIfDebug()
            return
        }
        
        // when holding CMD ...
        if self.graphUI.keypressState.isCommandPressed {
            // toggle selection
            if canvasItem.isSelected {
                canvasItem.deselect()
            } else {
                canvasItem.select()
            }
        }
        
        // when not holding CMD ...
        else {
            self.selectSingleCanvasItem(canvasItem)
        }
        
        // if we tapped a node, we're no longer moving it
        self.graphMovement.draggedCanvasItem = nil
        
        canvasItem.zIndex = self.highestZIndex + 1
    }
}
