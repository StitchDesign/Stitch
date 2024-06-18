//
//  LayerHoveredActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/19/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func updateMouseNodesPosition(mouseNodeIds: NodeIdSet,
                              gestureLocation: CGPoint?, // nil when hover or drag ends
                              velocity: StitchPosition? = nil, // nil when hover or drag ends
                              leftClick: Bool = false,
                              previewWindowSize: CGSize,
                              graphState: GraphState,
                              graphTime: TimeInterval) {

    let position: StitchPosition = gestureLocation.map {
        .init(width: $0.x - previewWindowSize.width/2,
              height: $0.y - previewWindowSize.height/2)
    }
    // `gestureLocation: nil` = hoverEnded
    ?? .zero

    // nil = drag or hover ended, so set to zero
    let finalVelocity = velocity ?? .zero

    let isMouseGestureEnd = !gestureLocation.isDefined || !velocity.isDefined

    if isMouseGestureEnd {
        graphState.graphUI.lastMouseNodeMovement = nil
    } else {
        graphState.graphUI.lastMouseNodeMovement = graphTime
    }

    for mouseNodeId in mouseNodeIds {
        if let node = graphState.getPatchNode(id: mouseNodeId) {
            // Always scalar
            node.getOutputRowObserver(MouseNodeOutputLocations.leftClick)?
                .updateValues([PortValue.bool(leftClick)])

            node.getOutputRowObserver(MouseNodeOutputLocations.position)?
                .updateValues([PortValue.position(position)])

            node.getOutputRowObserver(MouseNodeOutputLocations.velocity)?
                .updateValues([PortValue.position(finalVelocity)])

        } else {
            log("updateMouseNodesPosition: could not find mouse node \(mouseNodeId)")
        }
    }
}

struct LayerHovered: ProjectEnvironmentEvent {
    let location: CGPoint // HoverPhase.active(location)
    let velocity: CGPoint

    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {

        // log("LayerHovered: called")

        let mouseNodeIds: NodeIdSet = graphState.mouseNodes

        guard !mouseNodeIds.isEmpty else {
            // log("LayerHovered: no mouse nodes")
            return .noChange
        }

        updateMouseNodesPosition(mouseNodeIds: mouseNodeIds,
                                 gestureLocation: location,
                                 velocity: velocity.toCGSize,
                                 previewWindowSize: graphState.previewWindowSize,
                                 graphState: graphState,
                                 graphTime: graphState.graphStepState.graphTime)

        // Recalculate the graph
        graphState.calculate(mouseNodeIds)

        return .noChange
    }
}

struct LayerHoverEnded: ProjectEnvironmentEvent {
    func handle(graphState: GraphState,
                computedGraphState: ComputedGraphState,
                environment: StitchEnvironment) -> GraphResponse {
        // log("LayerHoverEnded: called")

        let mouseNodeIds: NodeIdSet = graphState.mouseNodes

        guard !mouseNodeIds.isEmpty else {
            // log("LayerHoverEnded: no mouse nodes")
            return .noChange
        }

        updateMouseNodesPosition(mouseNodeIds: mouseNodeIds,
                                 gestureLocation: nil, // hover-ended
                                 previewWindowSize: graphState.previewWindowSize,
                                 graphState: graphState,
                                 graphTime: graphState.graphStepState.graphTime)

        // Recalculate the graph
        graphState.calculate(mouseNodeIds)
        
        return .noChange
    }
}
