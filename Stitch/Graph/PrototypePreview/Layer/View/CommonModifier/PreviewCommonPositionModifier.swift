//
//  PreviewCommonPositionModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit


func getPinReceiverLayerViewModel(for pinnedLayerViewModel: LayerViewModel,
                                  from graph: GraphState) -> LayerViewModel? {

    let pinnedTo: LayerNodeId? = pinnedLayerViewModel.pinTo.getInteractionId
    
    // TODO: retrieve actual NodeViewModel for the `pinnedTo` id; do not assume .rectangle etc.
    let pinReceiver: NodeViewModel? = graph.layerNodes.values.first(where: { $0.layerNodeViewModel?.layer == .rectangle })
    
    guard let pinReceiver = pinReceiver else {
        log("getPinReceiverLayerViewModel: no pinReceiver for layer \(pinnedLayerViewModel)")
        return nil
    }
    
    // TODO: suppose View A (pinned) has a loop of 5, but View B (pin-receiver) has a loop of only 2; which pin-receiver view model should we return?
    let pinReceiverAtSameLoopIndex = pinReceiver.layerNodeViewModel?.previewLayerViewModels[safe: pinnedLayerViewModel.id.loopIndex]
    
    let firstPinReceiver = pinReceiver.layerNodeViewModel?.previewLayerViewModels.first
    
    return pinReceiverAtSameLoopIndex ?? firstPinReceiver
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
           let pinReceiverLayerViewModel = getPinReceiverLayerViewModel(for: viewModel,
                                                                        from: graph) {
            
            logInView("PreviewCommonPositionModifier: view model \(viewModel.layer) is pinned and had pin receiver")
            
            let pinPos = adjustPosition(
                size: viewModel.pinnedSize ?? .zero,
                position: (pinReceiverLayerViewModel.pinReceiverOrigin ?? .zero).toCGSize,
                anchor: viewModel.pinAnchor.getAnchoring ?? .topLeft,
                parentSize: pinReceiverLayerViewModel.pinReceiverSize ?? .zero)
            
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
