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
    let nodeId: LayerNodeId
    let highlightedSidebarLayers: LayerIdSet
    let scale: CGFloat
    
    static let baseBorderWidth = 2.0
    
    var isHighlighted: Bool {
        highlightedSidebarLayers.contains(nodeId)
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
    
    func body(content: Content) -> some View {
        content
            .border(.blue.opacity(isHighlighted ? 1 : 0),
                    width: borderWidth)
    }
}
