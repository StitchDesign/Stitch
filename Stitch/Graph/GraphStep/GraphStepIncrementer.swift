//
//  GraphStepIncrementer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine

extension GraphState: GraphStepManagerDelegate {
    func graphStepIncremented(elapsedProjectTime: TimeInterval,
                              frameCount: Int,
                              currentEstimatedFPS: StitchFPS) {
        // log("graphStepIncremented called")
        
        // Tracks whether any graph-recalc changes were actually made.
        // If no, we can return nil, which ensures no render cycles are made.
        var shouldRunGraph = false
        
        self.graphStepManager.lastGraphTime = elapsedProjectTime
        self.graphStepManager.lastGraphAnimationTime = elapsedProjectTime
        self.graphStepManager.estimatedFPS = currentEstimatedFPS
                
        var nodesToRunOnGraphStep = self.nodesToRunOnGraphStep
        
        let graphTime = self.graphStepManager.graphTime
        
        if self.graphMovement.shouldRun {
            // 60 FPS = 0.0167 seconds elapse between graph steps
            // 120 FPS = 0.00833 seconds elapse between graph steps
            // We need to require that at least greater than 1/120th of a second has elapsed, before we can run the graph momentum animation again.
            if (graphTime - self.graphUI.lastMomentumRunTime) > 0.010 {
                self.handleGraphMovementOnGraphStep()
                self.graphUI.lastMomentumRunTime = graphTime
            }
        }
        
        // If we have actively-interacted-with mouse nodes, we may need reset their velocity outputs
        if let lastMouseMovement = self.graphUI.lastMouseNodeMovement,
           (graphTime - lastMouseMovement) > DRAG_NODE_VELOCITY_RESET_STEP {
            let mouseNodeIds = self.mouseNodes
            for mouseNodeId in mouseNodeIds {
                if let mouseNode = self.getPatchNode(id: mouseNodeId) {
                    mouseNode.getOutputRowObserver(MouseNodeOutputLocations.velocity)?
                        .updateValues([.position(.zero)],
                                      activeIndex: self.activeIndex,
                                      isVisibleInFrame: mouseNode.isVisibleInFrame)
                }
            }
            
            nodesToRunOnGraphStep = nodesToRunOnGraphStep.union(mouseNodeIds)
        }
        
        if nodesToRunOnGraphStep.isEmpty && !shouldRunGraph {
            /*
             Usually we can return `nil` if there were no must run nodes
             or if we didn't need to recalculate the graph;
             but if we modified the Catalyst keypress stream,
             then we need to pass on that GraphUIState change,
             *even if there are no keyboard nodes on the graph*.
             */
            return
        }
        
        //        #if DEV_DEBUG
        //        log("graphStepIncremented: calculating \(nodesToRunOnGraphStep)")
        //        #endif
                        
        // Use this caller directly, since it exposes the API we want
        // without having to pass parameters through a bunch of other `calculateGraph` functions.
        self.calculate(from: nodesToRunOnGraphStep)
    }
}
