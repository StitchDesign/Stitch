//
//  PreviewSidebarHighlightModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Note: highlight border must be placed before `.position` .offset and
struct PreviewSidebarHighlightModifier: ViewModifier {
    @Bindable var viewModel: LayerViewModel
    
    let isPinnedViewRendering: Bool
    
    let nodeId: LayerNodeId
    let highlightedSidebarLayers: LayerIdSet
    let scale: CGFloat
    
    static let baseBorderWidth = 2.0
    
    var isPinned: Bool {
        viewModel.isPinned.getBool ?? false
    }
    
    // ALSO: if this is View A and it is not being generated at the top level,
    // then we should hide the view
    var isGhostView: Bool {
        isPinned && !isPinnedViewRendering
    }
    
    var isHighlighted: Bool {
        // TODO: reads here cause a crash nodes once connected to layer inputs nodes
        /// https://github.com/StitchDesign/Stitch/issues/264
//        highlightedSidebarLayers.contains(nodeId)
        false
    }
    
    // Subtract out scale, so that line is always same width
    var borderWidth: CGFloat {
        if scale > 1 {
            return Self.baseBorderWidth - (Self.baseBorderWidth/scale)
        }
        // Don't factor out scale if scale is negative or just 1
        else {
            return Self.baseBorderWidth
        }
    }
    
    var borderOpacity: CGFloat {
        (isHighlighted && !isGhostView) ? 1 : 0
    }
    
    func body(content: Content) -> some View {
        content
            .border(.blue.opacity(borderOpacity),
                    width: borderWidth)
    }
}
