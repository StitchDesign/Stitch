//
//  LayerHoveredActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/19/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension StitchDocumentViewModel {
    @MainActor
    func updateMouseNodesPosition(mouseNodeIds: NodeIdSet,
                                  gestureLocation: CGPoint?, // nil when hover or drag ends
                                  velocity: StitchPosition? = nil, // nil when hover or drag ends
                                  leftClick: Bool = false,
                                  previewWindowSize: CGSize,
                                  graphTime: TimeInterval) {
        
        let position: StitchPosition = gestureLocation.map {
            .init(x: $0.x - previewWindowSize.width/2,
                  y: $0.y - previewWindowSize.height/2)
        }
        // `gestureLocation: nil` = hoverEnded
        ?? .zero
        
        // nil = drag or hover ended, so set to zero
        let finalVelocity = velocity ?? .zero
        
        let isMouseGestureEnd = !gestureLocation.isDefined || !velocity.isDefined
        
        if isMouseGestureEnd {
            self.graphUI.lastMouseNodeMovement = nil
        } else {
            self.graphUI.lastMouseNodeMovement = graphTime
        }
        
        for mouseNodeId in mouseNodeIds {
            if let node = self.graph.getPatchNode(id: mouseNodeId)?.patchCanvasItem {
                // Always scalar
                node.outputViewModels[safe: MouseNodeOutputLocations.leftClick]?.rowDelegate?
                    .updateValues([PortValue.bool(leftClick)])
                
                node.outputViewModels[safe: MouseNodeOutputLocations.position]?.rowDelegate?
                    .updateValues([PortValue.position(position)])
                
                node.outputViewModels[safe: MouseNodeOutputLocations.velocity]?.rowDelegate?
                    .updateValues([PortValue.position(finalVelocity)])
                
            } else {
                log("updateMouseNodesPosition: could not find mouse node \(mouseNodeId)")
            }
        }
    }
}

struct LayerHovered: StitchDocumentEvent {
    let location: CGPoint // HoverPhase.active(location)
    let velocity: CGPoint

    func handle(state: StitchDocumentViewModel) {

        // log("LayerHovered: called")

        let mouseNodeIds: NodeIdSet = state.visibleGraph.mouseNodes

        guard !mouseNodeIds.isEmpty else {
            // log("LayerHovered: no mouse nodes")
            return
        }

        state
            .updateMouseNodesPosition(mouseNodeIds: mouseNodeIds,
                                      gestureLocation: location,
                                      velocity: velocity,
                                      previewWindowSize: state.previewWindowSize,
                                      graphTime: state.graphStepState.graphTime)

        // Recalculate the graph
        state.calculate(mouseNodeIds)
    }
}

struct LayerHoverEnded: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        // log("LayerHoverEnded: called")

        let mouseNodeIds: NodeIdSet = state.visibleGraph.mouseNodes

        guard !mouseNodeIds.isEmpty else {
            // log("LayerHoverEnded: no mouse nodes")
            return
        }

        state
            .updateMouseNodesPosition(mouseNodeIds: mouseNodeIds,
                                      gestureLocation: nil, // hover-ended
                                      previewWindowSize: state.previewWindowSize,
                                      graphTime: state.graphStepState.graphTime)

        // Recalculate the graph
        state.calculate(mouseNodeIds)
    }
}
