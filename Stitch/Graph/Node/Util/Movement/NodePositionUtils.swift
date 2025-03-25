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
    @MainActor
    func graphBaseViewSize(_ graphMovement: GraphMovementObserver) -> CGSize? {
        guard let nodeSize = self.sizeByLocalBounds else {
            return nil
        }
        
        let denominator = graphMovement.zoomData
        
        return .init(width: nodeSize.width / denominator,
                     height: nodeSize.height / denominator)
    }
}

extension StitchDocumentViewModel {
    
    // fka `CanvasItemViewModel.isTapped`
    @MainActor
    func canvasItemTapped(_ canvasItem: CanvasItemViewModel) {
        
        let canvasItemId: CanvasItemId = canvasItem.id
        
        log("canvasItemTapped: id: \(self.id)")
        let graph = self.visibleGraph
        
        // when holding CMD ...
        // TODO: pass this down from the gesture handler or fix key listening
        if self.keypressState.isCommandPressed {
            // toggle selection
            let isSelected = graph.selection.selectedCanvasItems.contains(canvasItemId)
            if isSelected {
                graph.deselectCanvasItem(canvasItemId)
            } else {
                graph.selectCanvasItem(canvasItemId)
            }
        }
        
        // when not holding CMD ...
        else {
            graph.selectSingleCanvasItem(canvasItemId)
        }
        
        // if we tapped a node, we're no longer moving it
        self.graphMovement.draggedCanvasItem = nil
        
        canvasItem.zIndex = graph.highestZIndex + 1
    }
}
