//
//  GraphStepIncrementer.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine
import simd

extension StitchDocumentViewModel: GraphStepManagerDelegate {
    func graphStepIncremented(elapsedProjectTime: TimeInterval,
                              frameCount: Int,
                              currentEstimatedFPS: StitchFPS) {
        
        self.graphStepManager.lastGraphTime = elapsedProjectTime
        self.graphStepManager.lastGraphAnimationTime = elapsedProjectTime
        self.graphStepManager.estimatedFPS = currentEstimatedFPS
        
        // Very important: reverse pulse coercions from last graph step
        self.graph.reversePulseCoercionsFromPreviousGraphStep()
        
        // Evaluate the graph
        self.graph.calculateOnGraphStep()
                
        // Update fields every 30 frames
        if !self.visibleGraph.portsToUpdate.isEmpty &&
            frameCount % Self.fieldsFrequency(from: self.graphMovement.zoomData) == 0 {
            self.visibleGraph.updatePortViews()
        }
    }
    
    static func fieldsFrequency(from zoom: CGFloat) -> Int {
        if zoom < 0.25 {
            return 600
        } else if zoom < 0.4 {
            return 120
        } else if zoom < 0.5 {
            return 30
        }
        
        // Most frequent: 30 frames on 120 FPS devices
        return 4
    }
}

extension GraphState {
    
    /*
     Reverse the previous graph step's pulsed outputs before evaluating the graph on this graph step.
     
     TODO: maybe inaccurate for cases where specific loop-indices pulse at different times?
     e.g. LoopBuilder with inputs from RepeatingPulse nodes at different frequencies.
     
     TODO: inaccurate for cycles, since graph eval of a cycle is split across 2 different graph steps and so some nodes in the cycle may not receive the pulse if we wipe the pulse after only 1 graph step.
     See https://github.com/StitchDesign/Stitch--Old/issues/7047
     */
    @MainActor
    func reversePulseCoercionsFromPreviousGraphStep() {
        self.pulsedOutputs.forEach { (pulsedOutput: NodeIOCoordinate) in
            // Cannot recalculate full node in some examples (like delay node)
            // so we just update downstream nodes
            if let node = self.getNode(pulsedOutput.nodeId),
               let currentOutputs = node
                .getOutputRowObserver(for: pulsedOutput.portType)?
                .allLoopedValues {
                
                // Reverse the values in the downstream inputs
                let changedDownstreamInputIds = self
                    .updateDownstreamInputs(sourceNode: node,
                                            upstreamOutputValues: currentOutputs,
                                            mediaList: nil,
                                            // True, since we reversed the pulse effect?
                                            upstreamOutputChanged: true,
                                            outputCoordinate: pulsedOutput)
                
                let changedDownstreamNodeIds = Set(changedDownstreamInputIds.map(\.nodeId)).toSet
                self.scheduleForNextGraphStep(changedDownstreamNodeIds)
            } // if let
        }
        
        // Finally, wipe pulsed-outputs
        self.pulsedOutputs = .init()
    }
}


// DEBUG HELPERS
extension NodeViewModel {
    @MainActor
    func allInputFieldObserverValues() -> FieldValues {
        self.allInputRowViewModels.allFieldObserverValues()
    }
    
    @MainActor
    func allOutputFieldObserverValues() -> FieldValues {
        self.allOutputRowViewModels.allFieldObserverValues()
    }
}

extension Array where Element: NodeRowViewModel {
    @MainActor
    func allFieldObserverValues() -> FieldValues {
        self.flatMap {
            $0.cachedFieldValueGroups.flatMap {
                $0.fieldObservers.map {
                    $0.fieldValue
                }
            }
        }
    }
}

extension GraphState {
    @MainActor func calculateOnGraphStep() {
        var nodesToRunOnGraphStep = self.nodesToRunOnGraphStep
        // log("calculateOnGraphStep: nodesToRunOnGraphStep: \(nodesToRunOnGraphStep)")
        
        let graphTime = self.graphStepManager.graphTime
        let components = self.nodes.values
            .compactMap { $0.nodeType.componentNode }
        
        // If we have actively-interacted-with mouse nodes, we may need reset their velocity outputs
        if let lastMouseMovement = self.documentDelegate?.lastMouseNodeMovement,
           (graphTime - lastMouseMovement) > DRAG_NODE_VELOCITY_RESET_STEP {
            
            for mouseNodeId in self.mouseNodes {
                if let mouseNodeState = self.getPatchNode(id: mouseNodeId)?.ephemeralObservers?.first as? MouseNodeState {
                    
                    mouseNodeState.velocity = .zero
                    nodesToRunOnGraphStep.insert(mouseNodeId)
                }
            }
            
//            nodesToRunOnGraphStep = nodesToRunOnGraphStep.union(mouseNodeIds)
            
            // Add components containing mouse nodes
            nodesToRunOnGraphStep = components.reduce(into: nodesToRunOnGraphStep) { nodesSet, component in
                if !component.graph.mouseNodes.isEmpty,
                   let nodeId = component.nodeDelegate?.id {
                    nodesSet.insert(nodeId)
                }
            }
        }
        
        // Check if any components need to be run
        nodesToRunOnGraphStep = components.reduce(into: nodesToRunOnGraphStep) { nodesSet, component in
            if !component.graph.nodesToRunOnGraphStep.isEmpty,
               let nodeId = component.nodeDelegate?.id {
                nodesSet.insert(nodeId)
            }
        }

        self.nodes.values.forEach { node in
            // Checks for transform updates each graph step--needed due to lack of transform publishers
            node.checkARTransformUpdate(self)
        }
        
        if nodesToRunOnGraphStep.isEmpty {
            /*
             Usually we can return `nil` if there were no must run nodes
             or if we didn't need to recalculate the graph;
             but if we modified the Catalyst keypress stream,
             then we need to pass on that StitchDocumentViewModel change,
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

extension NodeViewModel {
    /// Checks if some 3D model's transform was changed due to external event like gestures.
    /// Solves problem where gestures won't update fields directly, and without available publishers we have to manually check on graph step.
    @MainActor
    func checkARTransformUpdate(_ graph: GraphState) {
        guard let layerNode = self.nodeType.layerNode,
              Layer.layers3D.contains(layerNode.layer) else {
            return
        }
        
        let containsModelChange = layerNode.previewLayerViewModels
            .contains(where: { previewLayer in
                guard let model = previewLayer.mediaObject?.model3DEntity?.containerEntity,
                      let lastSavedTransform = previewLayer.transform3D.getTransform else {
                    return false
                }
                
                let inferredTransform = model.transform.matrix
                
                if inferredTransform != simd_float4x4(from: lastSavedTransform) {
                    // Update port value manually if transform changed
                    previewLayer.transform3D = .transform(.init(from: inferredTransform))
                    
                    // MARK:  Apply transform to entity but do NOT update the transform instance property, which enables prototype restart functionality
                    model._applyMatrix(newMatrix: inferredTransform)
                    return true
                }
                
                return false
            })
        
        if containsModelChange {
            let newValues = layerNode.previewLayerViewModels
                .map { $0.transform3D }
            layerNode.transform3DPort.updatePortValues(newValues)
            layerNode.transform3DPort.updateAllRowObserversPortViewModels(graph)
        }
    }
}

extension LayerInputObserver {
    @MainActor
    func updateAllRowObserversPortViewModels(_ graph: GraphState) {
        switch self.mode {
        case .packed:
            self._packedData.rowObserver.updatePortViewModels(graph)
        case .unpacked:
            self._unpackedData.allPorts.forEach {
                $0.rowObserver.updatePortViewModels(graph)
            }
        }
    }
}
