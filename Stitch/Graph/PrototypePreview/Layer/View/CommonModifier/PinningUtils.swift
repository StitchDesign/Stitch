//
//  PinningUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/23/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI




// MARK: POSITIONING

func getPinReceiverData(for pinnedLayerViewModel: LayerViewModel,
                        from graph: GraphState) -> PinReceiverData? {

    log("getPinReceiverData: pinned layer \(pinnedLayerViewModel.layer) had pinTo of \(pinnedLayerViewModel.pinTo)")
                
    guard let pinnedTo: PinToId = pinnedLayerViewModel.pinTo.getPinToId else {
        log("getPinReceiverData: no pinnedTo for layer \(pinnedLayerViewModel.layer)")
        return graph.rootPinReceiverData
    }
        
    switch pinnedTo {
    
    case .root:
        log("getPinReceiverData: WILL RETURN ROOT CASE")
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
