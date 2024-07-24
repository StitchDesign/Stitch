//
//  PreviewCommonPositionModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

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
        
        if viewModel.isPinned {
            logInView("PreviewCommonPositionModifier: view model \(viewModel.layer) is pinned")
            // if this view is pinned, ASSUME IT IS PINNED TO THE FIRST RECTANGLE LAYER NODE in graph state
            if let pinReceiver: NodeViewModel = graph.layerNodes.values.first(where: { $0.layerNodeViewModel?.layer == .rectangle }) {
                
                if let pinReceiverLayerViewModel: LayerViewModel = pinReceiver.layerNodeViewModel?.previewLayerViewModels[safe: viewModel.id.loopIndex] {
                    
                    let pinPos = adjustPosition(
                        size: viewModel.pinnedSize ?? .zero,
                        position: (pinReceiverLayerViewModel.pinReceiverOrigin ?? .zero).toCGSize,
                        anchor: .topLeft, // default for now
                        parentSize: pinReceiverLayerViewModel.pinReceiverSize ?? .zero)
                    
                    content
                        .position(x: pinPos.width, y: pinPos.height)
                    
                } // if let pinReceiverLayerViewModel
                else {
                    logInView("PreviewCommonPositionModifier: no pinReceiverLayerViewModel")
                }
                
            } // if let pinReceiver 
            else {
                logInView("PreviewCommonPositionModifier: no pinReceiver")
            }
                        
        } else {
            logInView("PreviewCommonPositionModifier: regular")
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
