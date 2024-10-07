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

// Note: previously we had a side-effect delay to work around some issues with `.buttonStyle(.plain)`'s auto animation and a GraphSchema-update interrupting double tap. These issues now seem to be resolved.
extension CanvasItemViewModel {
    func adjustPosition(center: CGPoint) {
        let nodeSize = self.bounds.graphBaseViewBounds.size
        
        self.position = gridAlignedPosition(center: center,
                                            nodeSize: nodeSize)
        self.previousPosition = self.position
    }
    
    @MainActor
    func isTapped(document: StitchDocumentViewModel) {
        log("canvasItemTapped: id: \(self.id)")
        
        // when holding CMD ...
        // TODO: pass this down from the gesture handler or fix key listening
        if document.keypressState.isCommandPressed {
            // toggle selection
            if self.isSelected {
                self.deselect()
            } else {
                self.select()
            }
        }
        
        // when not holding CMD ...
        else {
            document.visibleGraph.selectSingleCanvasItem(self)
        }
        
        // if we tapped a node, we're no longer moving it
        document.graphMovement.draggedCanvasItem = nil
        
        self.zIndex = document.visibleGraph.highestZIndex + 1
    }
}
