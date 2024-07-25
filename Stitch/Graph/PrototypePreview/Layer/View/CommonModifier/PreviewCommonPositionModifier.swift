//
//  PreviewCommonPositionModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit


func getPinReceiverData(for pinnedLayerViewModel: LayerViewModel,
                        from graph: GraphState) -> PinReceiverData? {

    guard let pinnedTo: LayerNodeId = pinnedLayerViewModel.pinTo.getInteractionId else {
        log("getPinReceiverLayerViewModel: no pinnedTo for layer \(pinnedLayerViewModel)")
        return nil
        
        // Testing .parent and .root cases: if no pinnedTo, then choose
    }
    
    guard let pinReceiver = graph.layerNodes.get(pinnedTo.id) else {
        log("getPinReceiverLayerViewModel: no pinReceiver for layer \(pinnedLayerViewModel)")
        return nil
    }
    
    // TODO: suppose View A (pinned) has a loop of 5, but View B (pin-receiver) has a loop of only 2; which pin-receiver view model should we return?
    let pinReceiverAtSameLoopIndex = pinReceiver.layerNodeViewModel?.previewLayerViewModels[safe: pinnedLayerViewModel.id.loopIndex]
    
    let firstPinReceiver = pinReceiver.layerNodeViewModel?.previewLayerViewModels.first
    
    guard let pinReceiverLayerViewModel = (pinReceiverAtSameLoopIndex ?? firstPinReceiver) else {
        log("getPinReceiverLayerViewModel: no pinReceiver layer view model for layer \(pinnedLayerViewModel)")
        return nil
    }
    
    guard let pinReceiverSize = pinReceiverLayerViewModel.pinReceiverSize,
          let pinReceiverOrigin = pinReceiverLayerViewModel.pinReceiverOrigin,
          let pinReceiverCenter = pinReceiverLayerViewModel.pinReceiverCenter,
          let pinReceiverRotationX = pinReceiverLayerViewModel.rotationX.getNumber,
          let pinReceiverRotationY = pinReceiverLayerViewModel.rotationY.getNumber,
          let pinReceiverRotationZ = pinReceiverLayerViewModel.rotationZ.getNumber else {
        log("getPinReceiverLayerViewModel: missing pinReceiver size, origin and/or center for layer \(pinnedLayerViewModel)")
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

struct PreviewCommonPositionModifier: ViewModifier {
    
    // Needed so that Pinned View A can retrieve View B's position, size, center and Ghost View A's
    @Bindable var graph: GraphState
    
    /*
    Need more information for pinning.
     
     PinnedViewA -- always lives at top-level; position determined by ViewB's + pinAnchor
     GhostViewA -- used to read the parent-affected size etc.
     ViewB -- no changes
     */
    @Bindable var viewModel: LayerViewModel
    
    // Is this view a child of a group that uses HStack, VStack or Grid? If so, we ignore this view's position.
    // TODO: use .offset instead of .position when layer is a child
    let parentDisablesPosition: Bool

    // Position already adjusted by anchoring
    
    // NOTE: for a pinned view, `pos` will be something adjusted to the pinReceiver's anchoring, size and position
    
    var pos: StitchPosition
            

    func body(content: Content) -> some View {
        
        if viewModel.isPinned.getBool ?? false,
//           let pinReceiverLayerViewModel = getPinReceiverData(for: viewModel, from: graph) {
           let pinReceiverData = getPinReceiverData(for: viewModel, from: graph) {
            
            logInView("PreviewCommonPositionModifier: view model \(viewModel.layer) is pinned and had pin receiver")
            
//            let pinPos = adjustPosition(
//                size: viewModel.pinnedSize ?? .zero,
//                position: (pinReceiverLayerViewModel.pinReceiverOrigin ?? .zero).toCGSize,
//                anchor: viewModel.pinAnchor.getAnchoring ?? .topLeft,
//                parentSize: pinReceiverLayerViewModel.pinReceiverSize ?? .zero)
            
            let pinPos = getPinnedViewPosition(pinnedLayerViewModel: viewModel,
                                               pinReceiverData: pinReceiverData)
            
            content
                .position(x: pinPos.width, y: pinPos.height)
            
        } else {
            logInView("PreviewCommonPositionModifier: regular: \(viewModel.layer)")
            // Ghost views do not use .position modifier, but it doesn't matter;
            // we only read a Ghost View's size
            //        if parentDisablesPosition || isGhostView {
            if parentDisablesPosition {
                content
            } else {
                content
                    .position(x: pos.width, y: pos.height)
            }
        }
        
      
    }
}
