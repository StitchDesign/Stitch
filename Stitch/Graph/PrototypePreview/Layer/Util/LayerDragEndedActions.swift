//
//  LayerDragEndedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/24/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

//typealias LayerIndexToPosition = [PreviewCoordinate: StitchPosition]

/*
 User stopped dragging a layer in the preview window.

 Dispatched from SwiftUI DragGesture.onEnded;
 handles both drag and scroll interactions.
 */
extension GraphState {
    @MainActor
    func layerDragEnded(interactiveLayer: InteractiveLayer,
                        parentSize: CGSize,
                        childSize: CGSize,
                        document: StitchDocumentViewModel) {
        // log("layerDragEnded: interactiveLayer.id: \(interactiveLayer.id)")
         // log("layerDragEnded CALLED")

        let previewWindowSize = document.previewWindowSize
        
        var nodesToRecalculate = NodeIdSet()
        
        let pressInteractionIdSet: IdSet = self.getPressInteractionIds(for: interactiveLayer.id.layerNodeId)

        let dragInteractionIdSet: IdSet = getDragInteractionIds(for: interactiveLayer.id.layerNodeId)

        let scrollInteractionIdSet: IdSet = getScrollInteractionIds(for: interactiveLayer.id.layerNodeId)

        // Nodes to recalculate initialize with mouse nodes
        let mouseNodeIds: NodeIdSet = self.mouseNodes

        document
            .updateMouseNodesPosition(mouseNodeIds: mouseNodeIds,
                                      gestureLocation: nil,
                                      velocity: nil,
                                      leftClick: false,
                                      previewWindowSize: previewWindowSize,
                                      graphTime: self.graphStepState.graphTime)
        
        nodesToRecalculate = nodesToRecalculate.union(mouseNodeIds)
        
        interactiveLayer.handleLayerDragEnded()
             
        // e.g. `pressInteractionIdSet` may be empty, so it's fine to add an empty set.
        nodesToRecalculate = nodesToRecalculate.union(pressInteractionIdSet)
        nodesToRecalculate = nodesToRecalculate.union(dragInteractionIdSet)
        nodesToRecalculate = nodesToRecalculate.union(scrollInteractionIdSet)
        
        if dragInteractionIdSet.contains(interactiveLayer.id.layerNodeId.asNodeId) {
            
            self.activeDragInteraction.activeDragInteractionNodes = self.activeDragInteraction.activeDragInteractionNodes
                .subtracting(dragInteractionIdSet)
        } // if let
        
        // Recalculate the graph
        self.scheduleForNextGraphStep(nodesToRecalculate)
    }
}
