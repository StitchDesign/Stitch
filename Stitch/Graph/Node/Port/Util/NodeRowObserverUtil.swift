//
//  NodeRowObserverUtil.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/9/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine

// MARK: -- Extension methods that need some love

// TODO: we can't have a NodeRowObserver without also having a GraphDelegate (i.e. GraphState); can we pass down GraphDelegate to avoid the Optional unwrapping?
extension NodeRowViewModel {
    @MainActor
    var graphDelegate: GraphDelegate? {
        self.nodeDelegate?.graphDelegate
    }
    
    @MainActor
    var nodeKind: NodeKind {
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return .patch(.splitter)
        }
        
        return node.kind
    }
    
    @MainActor
    var isCanvasItemSelected: Bool {
        guard let graph = self.graphDelegate,
              let canvasId = self.canvasItemDelegate?.id else { return false }
        
        return graph.graphUI.selection.selectedCanvasItems.contains(canvasId)
    }
    
    /// If this is row is for a splitter node in a group node, and the group node is selected, then consider this splitter selected as well.
    // MARK: this is only for port/edge-color purposes; do not use this for e.g. node movement etc.
    // TODO: we only care about splitterType = .input or .output; add `splitterType` to `NodeDelegate`.
    @MainActor
    var isCanvasItemSelectedDeep: Bool {
        if self.nodeKind == .patch(.splitter),
           let parentId = self.canvasItemDelegate?.parentGroupNodeId,
           let graph = self.graphDelegate,
           let parentCanvas = graph.getNodeViewModel(parentId)?.patchCanvasItem,
           graph.graphUI.selection.selectedCanvasItems.contains(parentCanvas.id) {
            return true
        } else {
            return self.isCanvasItemSelected
        }
    }
    
    // for a single input observer, we call this.
    // 
    @MainActor
    var isConnectedToASelectedCanvasItem: Bool {
        guard let graph = self.graphDelegate else {
            return false
        }
        
        for connectedCanvasItemId in self.connectedCanvasItems {
            guard graph.graphUI.selection.selectedCanvasItems.contains(connectedCanvasItemId) else {
                continue
            }
            // Found connected canvas item that is selected
            return true
        }
        return false
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
}

extension NodeRowObserver {
    @MainActor
    func didInputsUpdate(newValues: PortValues,
                         oldValues: PortValues) {
        guard let node = self.nodeDelegate,
              let graph = node.graphDelegate,
              let document = graph.documentDelegate else {
            return
        }
        
        let graphTime = graph.graphStepState.graphTime
        let canCopyInputValues = node.kind.canCopyInputValues(portId: self.id.portId,
                                                              userVisibleType: node.userVisibleType)
        
        guard !newValues.isEmpty else {
            //            #if DEV_DEBUG
            //            fatalError()
            //            #endif
            return
        }

        // Some values for some node inputs (like delay node) can directly be copied into the input and must bypass the type coercion logic
        if canCopyInputValues {
            self.updateValues(newValues)
        } else {
            if let firstOriginalValues = oldValues.first {
                self.coerceUpdate(these: newValues,
                                  to: firstOriginalValues,
                                  oldValues: oldValues,
                                  currentGraphTime: graphTime)
            } else {
                fatalErrorIfDebug()
//                log("no old values for \(self.id)")
            }
        }

        // If we changed a camera direction/orientation input on a camera-using node (Camera or RealityKit),
        // then we may need to update GraphState.cameraSettings, CameraFeedManager etc.
        let coercedValues = self.allLoopedValues
        if node.kind.usesCamera,
           let originalValue = oldValues.first,
           let coercedValue = coercedValues.first {
            document.cameraInputChange(
                input: self.id,
                originalValue: originalValue,
                coercedValue: coercedValue)
        }
        
        if node.kind.isLayer,
           oldValues != coercedValues {
            let layerId = node.id.asLayerNodeId
            graph.assignedLayerUpdated(changedLayerNode: layerId)
        }
        
        // Update view ports
        graph.portsToUpdate.insert(NodePortType.input(self.id))
    }
}
