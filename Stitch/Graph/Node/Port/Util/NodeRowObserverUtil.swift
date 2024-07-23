//
//  NodeRowObserverUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit

// MARK: -- Extension methods that need some love

// TODO: we can't have a NodeRowObserver without also having a GraphDelegate (i.e. GraphState); can we pass down GraphDelegate to avoid the Optional unwrapping?
extension NodeRowObserver {
    
    @MainActor
    func getIsNodeSelected() -> Bool {
        self.nodeDelegate?.isSelected ?? false
    }
    
    //
    @MainActor
    func getIsNodeSelectedForPortColor() -> Bool {
        
        /*
         If this is row is for a splitter node in a group node, and the group node is selected, then consider this splitter selected as well.
         NOTE: this is only for port/edge-color purposes; do not use this for e.g. node movement etc.
         
         TODO: we only care about splitterType = .input or .output; add `splitterType` to `NodeDelegate`.
         */
        if self.nodeKind == .patch(.splitter),
           let parentId = self.nodeDelegate?.parentGroupNodeId,
           self.nodeDelegate?.graphDelegate?.getNodeViewModel(parentId)?.isSelected ?? false {
            return true
        } else {
            return self.getIsNodeSelected()
        }
    }
    
    @MainActor
    func getIsConnectedToASelectedNode() -> Bool {
        if let graph = self.nodeDelegate?.graphDelegate {
            return graph.isConnectedToASelectedNode(at: self)
        } else {
            log("NodeRowObserver: getIsConnectedToASelectedNode: could not retrieve delegates")
            return false
        }
    }
    
    @MainActor
    func getHasSelectedEdge() -> Bool {
        if let graph =  self.nodeDelegate?.graphDelegate {
            return graph.hasSelectedEdge(at: self)
        } else {
            log("NodeRowObserver: getHasSelectedEdge: could not retrieve delegates")
            return false
        }
    }

    @MainActor
    func getEdgeDrawingObserver() -> EdgeDrawingObserver {
        if let drawing = self.nodeDelegate?.graphDelegate?.edgeDrawingObserver {
            return drawing
        } else {
            log("NodeRowObserver: getEdgeDrawingObserver: could not retrieve delegates")
            return .init()
        }
    }
    
    @MainActor
    func didInputsUpdate(newValues: PortValues,
                         oldValues: PortValues) {
        guard let node = self.nodeDelegate,
              let graph = node.graphDelegate else {
            return
        }
        
        let activeIndex = graph.activeIndex
        let graphTime = graph.graphStepState.graphTime
        let canCopyInputValues = node.kind.canCopyInputValues(portId: self.id.portId)
        
        guard !newValues.isEmpty else {
            //            #if DEV_DEBUG
            //            fatalError()
            //            #endif
            return
        }

        var effects = SideEffects()

        // Some values for some node inputs (like delay node) can directly be copied into the input and must bypass the type coercion logic
        if canCopyInputValues {
            self.updateValues(newValues,
                                       activeIndex: activeIndex,
                                       isVisibleInFrame: node.isVisibleInFrame)
        } else {
            if let firstOriginalValues = oldValues.first {
                self.coerceUpdate(these: newValues,
                                           to: firstOriginalValues,
                                           currentGraphTime: graphTime,
                                           activeIndex: activeIndex,
                                           isVisible: node.isVisibleInFrame)
            } else {
                fatalErrorIfDebug()
            }
        }

        // If we changed a camera direction/orientation input on a camera-using node (Camera or RealityKit),
        // then we may need to update GraphState.cameraSettings, CameraFeedManager etc.
        let coercedValues = self.allLoopedValues
        if node.kind.usesCamera,
           let originalValue = oldValues.first,
           let coercedValue = coercedValues.first {
            graph.cameraInputChange(
                input: self.id,
                originalValue: originalValue,
                coercedValue: coercedValue)
        }
        
        if node.kind.isLayer,
           oldValues != coercedValues {
            let layerId = node.id.asLayerNodeId
            
            // TODO: return a proper (but non-DispatchQueue.main.async) side-effect? or just calculate graph directly?
            // https://github.com/vpl-codesign/stitch/issues/5528
//            dispatch(AssignedLayerUpdated(changedLayerNode: layerNodeId))
            // NOTE: this MUST BE RETURNED AS A SIDE-EFFECT; otherwise a graph-eval can trigger a node view model input update, which dispatches `AssignedLayerUpdated`, which then evaluates the graph again. (Just an issue for cycles?_
            
            // TODO: why does this seem to mess with the Monthly Stays cycle demo?
            effects.append({
                AssignedLayerUpdated(changedLayerNode: layerId)
            })
        }
        
        effects.processEffects()
    }
}
