//
//  PinningUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/23/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// MARK: SORTING

/*
 "A is pinned on top of B," "D is pinned on top of B"
 B -> A i.e. "pin-receiving layer -> pinned layer"
  
 Oval A has pinTo input loop = [B, B, C]
 Oval D has pinTo input loop = [C]
 
 pinMap will be [
     B: { A },
     C: { A, D },
 ]
 */
typealias PinMap = [LayerNodeId?: LayerIdSet]

extension VisibleNodesViewModel {
    
    // Note: PinMap is only for views with a PinToId that corresponds to some layer node; so e.g. `PinToId.root` needs to be handled separately
    @MainActor
    func getPinMap() -> PinMap {
        
        var pinMap = PinMap()
        
        // Iterate through all layer nodes, checking each layer node's pinTo input loop; turn that loop into entries in the PinMap
        self.layerNodes.forEach { (nodeId: NodeId, node: NodeViewModel) in
            
            // Iterate th
            node.layerNode?.previewLayerViewModels.forEach({ (viewModel: LayerViewModel) in
                                
                // have to check whether the viewModel is actually pinned as well
                if (viewModel.isPinned.getBool ?? false),
                   var pinToId = viewModel.pinTo.getPinToId {
                    
                    // `PinToId.root` case does not have a corresponding layer node,
                    //
                   let pinReceivingLayer = pinToId.asLayerNodeId(viewModel.id.layerNodeId, from: self)
                    
                    if pinReceivingLayer == nil && pinToId != .root {
                        log("getPinMap: had nil pin-receiving-layer but PinToId was not 'root'; will default to 'root'")
                        // e.g. The layer referred to by `pinReceivingLayer` was deleted
                        pinToId = .root
                    }
                    
                    let pinnedLayer = nodeId.asLayerNodeId
                    
                    log("getPinMap: pinMap was: \(pinMap)")
                    log("getPinMap: \(pinnedLayer) layer view model is pinned to layer \(pinnedLayer)")
                    
                    var current = pinMap.get(pinReceivingLayer) ?? .init()
                    log("getPinMap: current was: \(current)")
                    
                    current.insert(pinnedLayer)
                    log("getPinMap: current is now: \(current)")
                    
                    pinMap.updateValue(current, forKey: pinReceivingLayer)
                    log("getPinMap: pinMap is now: \(pinMap)")
            
                }
            })
        } // self.layerNodes.forEach
        
        return pinMap
    }
}


// MARK: POSITIONING

extension GraphState {
    var rootPinReceiverData: PinReceiverData {
        PinReceiverData(
            // anchoring
            size: self.previewWindowSize,

            origin: .zero, // should be okay, since preview window is root of PreviewWindowCoordinate space anyway?
            
            // rotation this will be ignored
            center: .zero,
            rotationX: .zero,
            rotationY: .zero,
            rotationZ: .zero)
    }
}

func getPinReceiverData(for pinnedLayerViewModel: LayerViewModel,
                        from graph: GraphState) -> PinReceiverData? {

    log("getPinReceiverData: pinned layer \(pinnedLayerViewModel.layer) had pinTo of \(pinnedLayerViewModel.pinTo)")
                
    guard let pinnedTo: PinToId = pinnedLayerViewModel.pinTo.getPinToId else {
        log("getPinReceiverData: no pinnedTo for layer \(pinnedLayerViewModel.layer)")
        return graph.rootPinReceiverData
    }
        
    switch pinnedTo {
    
    case .root:
        return graph.rootPinReceiverData
    
        // Note: PinTo = Parent is perhaps redundant vs layer's Anchoring, which is always relative to parent
        // Worst case we can just remove this enum case in the next migration; Root still represents a genuinely new scenario
    case .parent:
        if let layerNode = graph.getNode(pinnedLayerViewModel.id.layerNodeId.asNodeId)?.layerNode,
              let parent = layerNode.layerGroupId {
            return getPinReceiverData(pinReceiverId: parent.asLayerNodeId,
                                      for: pinnedLayerViewModel,
                                      from: graph)
        } else {
            return graph.rootPinReceiverData
        }
        
    case .layer(let x):
        return getPinReceiverData(pinReceiverId: x,
                                  for: pinnedLayerViewModel,
                                  from: graph)
    }
}

extension PinToId {
    // nil: either pinToId = root or  pinToId could not be found
    func asLayerNodeId(_ pinnedViewId: LayerNodeId,
                       from graph: VisibleNodesViewModel) -> LayerNodeId? {
        switch self {
        case .root:
            return nil // root has no associated layer node id
        case .layer(let x):
            // Confirm that the layer exists; else return `nil`
            guard (graph.getNode(x.asNodeId)?.layerNode.isDefined ?? false) else {
                log("PinToId.asLayerNodeId: did not have layer node for pinToId.layer \(x)")
                return nil
            }
            return x
        case .parent:
            return graph.getNode(pinnedViewId.asNodeId)?.layerNode?.layerGroupId?.asLayerNodeId
        }
    }
}

func getPinReceiverData(pinReceiverId: LayerNodeId,
                        for pinnedLayerViewModel: LayerViewModel,
                        from graph: GraphState) -> PinReceiverData? {
    
    guard let pinReceiver = graph.layerNodes.get(pinReceiverId.id) else {
        log("getPinReceiverData: no pinReceiver for layer \(pinnedLayerViewModel.layer)")
        return graph.rootPinReceiverData
    }
    
    // TODO: suppose View A (pinned) has a loop of 5, but View B (pin-receiver) has a loop of only 2; which pin-receiver view model should we return?
    let pinReceiverAtSameLoopIndex = pinReceiver.layerNodeViewModel?.previewLayerViewModels[safe: pinnedLayerViewModel.id.loopIndex]
    
    let firstPinReceiver = pinReceiver.layerNodeViewModel?.previewLayerViewModels.first
    
    guard let pinReceiverLayerViewModel = (pinReceiverAtSameLoopIndex ?? firstPinReceiver) else {
        log("getPinReceiverData: no pinReceiver layer view model for layer \(pinnedLayerViewModel)")
        return nil
    }
    
    guard let pinReceiverSize = pinReceiverLayerViewModel.pinReceiverSize,
          let pinReceiverOrigin = pinReceiverLayerViewModel.pinReceiverOrigin,
          let pinReceiverCenter = pinReceiverLayerViewModel.pinReceiverCenter,
          let pinReceiverRotationX = pinReceiverLayerViewModel.rotationX.getNumber,
          let pinReceiverRotationY = pinReceiverLayerViewModel.rotationY.getNumber,
          let pinReceiverRotationZ = pinReceiverLayerViewModel.rotationZ.getNumber else {
        log("getPinReceiverData: missing pinReceiver size, origin and/or center for layer \(pinnedLayerViewModel.layer)")
        return nil
    }
    
    return PinReceiverData(
        // anchoring
        size: pinReceiverSize,
        origin: pinReceiverOrigin,
        
        // rotation
        center: pinReceiverCenter,
        rotationX: pinReceiverRotationX,
        rotationY: pinReceiverRotationY,
        rotationZ: pinReceiverRotationZ)
}



func getPinnedViewPosition(pinnedLayerViewModel: LayerViewModel,
                           pinReceiverData: PinReceiverData) -> StitchPosition {
    
    adjustPosition(size: pinnedLayerViewModel.pinnedSize ?? .zero,
                   position: pinReceiverData.origin.toCGSize,
                   anchor: pinnedLayerViewModel.pinAnchor.getAnchoring ?? .topLeft,
                   parentSize: pinReceiverData.size)
}


// TODO: there must be a more elegant formula here
func getRotationAnchor(lengthA: CGFloat,
                       lengthB: CGFloat,
                       pointA: CGFloat,
                       pointB: CGFloat) -> CGFloat {
    
    // ASSUMES View B's rotation anchor is center i.e. `(0.5, 0.5)`
    let defaultAnchor = 0.5
    
    guard lengthA != lengthB else {
        // Default to center
        print("getRotationAnchor: length: defaultAnchor")
        return defaultAnchor
    }
    
    guard pointA != pointB else {
        // Default to center
        print("getRotationAnchor: point: defaultAnchor")
        return defaultAnchor
    }
    
    // e.g. if View B = 200 and View A = 800,
    // (i.e. pinned View A is larger than the View B which it is pinned to.)
    // then anchor diff (0.5)(1/4) i.e. 1/8 = 0.125
    let anchorDiff = defaultAnchor * (lengthB / lengthA)
    
    let aLarger = lengthA > lengthB
    let aBelowOrRight = pointA > pointB
    
    if aLarger {
        return aBelowOrRight ? anchorDiff : (1 - anchorDiff)
    } else {
        return aBelowOrRight ? (1 - anchorDiff) : anchorDiff
    }
}
