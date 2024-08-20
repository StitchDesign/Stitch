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
    
    let isPinnedViewRendering: Bool
    
    // Is this view a child of a group that uses HStack, VStack or Grid? If so, we ignore this view's position.
    // TODO: use .offset instead of .position when layer is a child
    let parentDisablesPosition: Bool

    // Position already adjusted by anchoring
    
    // NOTE: for a pinned view, `pos` will be something adjusted to the pinReceiver's anchoring, size and position
    
    var pos: StitchPosition
      
    var isPinned: Bool {
        viewModel.isPinned.getBool ?? false
    }
    
    var isGhostView: Bool {
        isPinned && !isPinnedViewRendering
    }
    
    var isPinnedView: Bool {
        isPinned && isPinnedViewRendering
    }

    func body(content: Content) -> some View {
        
        // The PinnedView rendering of a layer relies on information about the layer it is pinned to.
        if isPinnedView,
           let pinReceiverData = getPinReceiverData(for: viewModel, from: graph) {
            
             // logInView("PreviewCommonPositionModifier: view model \(viewModel.layer) \(viewModel.id) is pinned and had pin receiver")
            
            let pinPos = getPinnedViewPosition(pinnedLayerViewModel: viewModel,
                                               pinReceiverData: pinReceiverData)
            
            let pinOffset: CGSize = viewModel.pinOffset.getSize?.asCGSize ?? .zero
            
             // logInView("PreviewCommonPositionModifier: pinPos: \(pinPos)")
             // logInView("PreviewCommonPositionModifier: pinOffset: \(pinOffset)")
            
            content
                .position(x: pinPos.width, y: pinPos.height)
                .offset(x: pinOffset.width, y: pinOffset.height)
            
        } else {
            // logInView("PreviewCommonPositionModifier: regular: \(viewModel.layer)")
            
            // A non-PinnedView rendering of a layer uses .position unless:
            // 1. the layer is a child inside a group that uses a VStack or HStack, or
            // 2. it is a GhostView rendering
            if parentDisablesPosition || isGhostView {
                content
            } else {
                content
                    .position(x: pos.width, y: pos.height)
            }
        }
    }
}

//struct PreviewCommonPositionModifier: ViewModifier {
//    
//    // Is this view a child of a group that uses HStack, VStack or Grid? If so, we ignore this view's position.
//    // TODO: use .offset instead of .position when layer is a child
//    let parentDisablesPosition: Bool
//
//    // Position already adjusted by anchoring
//    var pos: StitchPosition
//    
//    func body(content: Content) -> some View {
//        if parentDisablesPosition {
//            content
//        } else {
//            content
//                .position(x: pos.width, y: pos.height)
//        }
//    }
//}
