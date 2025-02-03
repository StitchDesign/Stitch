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
        // log("graphStepIncremented called")
        
        self.graphStepManager.lastGraphTime = elapsedProjectTime
        self.graphStepManager.lastGraphAnimationTime = elapsedProjectTime
        self.graphStepManager.estimatedFPS = currentEstimatedFPS
        
        self.graph.calculateOnGraphStep()
        
        // Update fields every 30 frames
        if !self.visibleGraph.portsToUpdate.isEmpty &&
            frameCount % Self.fieldsFrequency(from: self.graphMovement.zoomData.zoom) == 0 {
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
    @MainActor func calculateOnGraphStep() {
        var nodesToRunOnGraphStep = self.nodesToRunOnGraphStep
        
        let graphTime = self.graphStepManager.graphTime
        let components = self.nodes.values
            .compactMap { $0.nodeType.componentNode }
        
        // If we have actively-interacted-with mouse nodes, we may need reset their velocity outputs
        if let lastMouseMovement = self.graphUI.lastMouseNodeMovement,
           (graphTime - lastMouseMovement) > DRAG_NODE_VELOCITY_RESET_STEP {
            let mouseNodeIds = self.mouseNodes
            for mouseNodeId in mouseNodeIds {
                if let mouseNode = self.getNodeViewModel(id: mouseNodeId) {
                    mouseNode.getOutputRowObserver(MouseNodeOutputLocations.velocity)?
                        .updateValues([.position(.zero)])
                }
            }
            
            nodesToRunOnGraphStep = nodesToRunOnGraphStep.union(mouseNodeIds)
            
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
            node.checkARTransformUpdate()
        }
        
        if nodesToRunOnGraphStep.isEmpty {
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

extension NodeViewModel {
    /// Checks if some 3D model's transform was changed due to external event like gestures.
    /// Solves problem where gestures won't update fields directly, and without available publishers we have to manually check on graph step.
    @MainActor
    func checkARTransformUpdate() {
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
            layerNode.transform3DPort.updateAllRowObserversPortViewModels()
        }
    }
}

extension LayerInputObserver {
    @MainActor
    func updateAllRowObserversPortViewModels() {
        switch self.mode {
        case .packed:
            self._packedData.rowObserver.updatePortViewModels()
        case .unpacked:
            self._unpackedData.allPorts.forEach {
                $0.rowObserver.updatePortViewModels()
            }
        }
    }
}
