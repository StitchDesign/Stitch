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
            // allGraphs = have to update all components etc., so that values flow up properly ?
            self.allGraphs.forEach { graph in
                
                if let mouseNode = graph.getPatchNode(id: mouseNodeId) {
                    // Note: a mouse node will only ever have a single ephemeral observer, since it has no inputs and cannot be assigned to a layer (only the preview window as a whole)
                    guard let ephemeralObservers: [MouseNodeState] = (mouseNode.ephemeralObservers as? [MouseNodeState]) else {
                        fatalErrorIfDebug() // should have
                        return
                    }
                    
                    assertInDebug(ephemeralObservers.count < 2)
                    
                    ephemeralObservers.forEach { (ephemeralObserver: MouseNodeState) in
                        ephemeralObserver.isDown = leftClick
                        ephemeralObserver.position = position
                        ephemeralObserver.velocity = finalVelocity
                    }
                }
            }
        }
    }

    @MainActor
    func layerHovered(location: CGPoint,
                      velocity: CGPoint) {
        
        // log("LayerHovered: called")
        self.allGraphs.forEach { graph in
            let mouseNodeIds: NodeIdSet = graph.mouseNodes
            
            guard !mouseNodeIds.isEmpty else {
                // log("LayerHovered: no mouse nodes")
                return
            }
            
            self.updateMouseNodesPosition(mouseNodeIds: mouseNodeIds,
                                          gestureLocation: location,
                                          velocity: velocity,
                                          previewWindowSize: self.previewWindowSize,
                                          graphTime: self.graphStepState.graphTime)
            
            // Recalculate the graph
            graph.scheduleForNextGraphStep(mouseNodeIds)
        }
    }
    
    @MainActor
    func layerHoverEnded() {
        // log("LayerHoverEnded: called")
        self.allGraphs.forEach { graph in
            let mouseNodeIds: NodeIdSet = graph.mouseNodes
            
            guard !mouseNodeIds.isEmpty else {
                // log("LayerHoverEnded: no mouse nodes")
                return
            }
            
            self.updateMouseNodesPosition(mouseNodeIds: mouseNodeIds,
                                          gestureLocation: nil, // hover-ended
                                          previewWindowSize: self.previewWindowSize,
                                          graphTime: self.graphStepState.graphTime)
            
            // Recalculate the graph
            graph.scheduleForNextGraphStep(mouseNodeIds)
        }
    }
}

