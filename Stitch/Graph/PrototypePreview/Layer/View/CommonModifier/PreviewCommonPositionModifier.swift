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
    
    // The lazy children in a ScrollView { LazyVGrid } are not loaded by .offset / .position modifier changes,
    // so we disable both .offset and .position when this layer is inside a scrollable adaptive grid.
    let parentIsScrollableGrid: Bool
    
    let parentSize: CGSize

    // Position already adjusted by anchoring
    
    // NOTE: for a pinned view, `pos` will be something adjusted to the pinReceiver's anchoring, size and position
    
    var pos: StitchPosition
    
    var isPinnedView: Bool {
        viewModel.isPinnedView && isPinnedViewRendering
    }

    func body(content: Content) -> some View {
        
        // The PinnedView rendering of a layer relies on information about the layer it is pinned to.
        if isPinnedView,
           let pinReceiverData = graph.getPinReceiverData(for: viewModel) {
            
             // logInView("PreviewCommonPositionModifier: view model \(viewModel.layer) \(viewModel.id) is pinned and had pin receiver")
            
            let pinPos = getPinnedViewPosition(pinnedLayerViewModel: viewModel,
                                               pinReceiverData: pinReceiverData)
            
            // Ghost view equivalent of pin view passes position info for calculating
            // final position location
            let ghostViewPosition = self.viewModel.readMidPosition
            let pinPositionOffset = pinPos - ghostViewPosition
            
            // Input value of pin offset
            let pinOffset: CGSize = viewModel.pinOffset.getSize?.asCGSize ?? .zero
            
             // logInView("PreviewCommonPositionModifier: pinPos: \(pinPos)")
             // logInView("PreviewCommonPositionModifier: pinOffset: \(pinOffset)")
            
            positioningView(content)
                .offset(x: pinPositionOffset.x, y: pinPositionOffset.y)
                .offset(x: pinOffset.width, y: pinOffset.height)
            
        } else {
            positioningView(content)
        }
    }
    
    @ViewBuilder func positioningView(_ content: Content) -> some View {
        // logInView("PreviewCommonPositionModifier: regular: \(viewModel.layer)")
        if parentIsScrollableGrid {
            content
        } else if parentDisablesPosition {
           let offset = viewModel.offsetInGroup.getSize?.asCGSize(parentSize) ?? .zero
            content
               .offset(x: offset.width, y: offset.height)
        } else {
            content
                .position(x: pos.x, y: pos.y)
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
