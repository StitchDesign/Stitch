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
    var pos: StitchPosition
    
//    var isGhostView: Bool = false
        

    func body(content: Content) -> some View {
        
        if viewModel.isPinned {
            
            
            
        } else {
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
