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
    func nodeTapped(_ node: NodeViewModel) {
        let id = node.id
        log("nodeTapped: id: \(id)")
        
        guard let node = self.getNodeViewModel(id) else {
            fatalErrorIfDebug()
            return
        }
        
        // when holding CMD ...
        if self.graphUI.keypressState.isCommandPressed {
            // toggle selection
            self.setNodeSelection(node, to: !node.isSelected)
        }
        
        // when not holding CMD ...
        else {
            self.selectSingleNode(node)
        }
        
        // if we tapped a node, we're no longer moving it
        self.graphMovement.draggedNode = nil
        
        node.zIndex = self.highestZIndex + 1
     
        // Why would we write-to-file when we tap a node? Does that ephemeral state really need to be cross-synced?
//        self.encodeProjectInBackground()
    }
}
