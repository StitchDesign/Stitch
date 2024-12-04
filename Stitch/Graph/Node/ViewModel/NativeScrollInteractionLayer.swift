//
//  NativeScrollInteractionLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/3/24.
//

import SwiftUI

// Lives as optional type on InteractionLayer, which lives on LayerViewModel.
// Created when scroll interaction is assigned to a layer.
// Destroyed when scroll interaction de-assigned.

@Observable
final class NativeScrollInteractionLayer: Sendable {
    
    @MainActor var rawScrollViewOffset: CGPoint = .zero
    
    // TODO: DEC 3: Do you need all the inputs of the scroll interaction node here? ... everything
    
    // determines [.vertical, .horizontal] scroll axes for ScrollView
    @MainActor var xScrollEnabled: Bool = NativeScrollInteractionNode.defaultScrollXEnabled
    @MainActor var yScrollEnabled: Bool = NativeScrollInteractionNode.defaultScrollYEnabled
    
    // custom content size; ignore a dimension if 0
    @MainActor var contentSize: CGSize = .zero
    
    
    // JUMP
    
    // jump style
    @MainActor var jumpStyleX: ScrollJumpStyle = .scrollJumpStyleDefault
    @MainActor var jumpStyleY: ScrollJumpStyle = .scrollJumpStyleDefault

    // pulse
    // e.g. `nativeScrollInteractionLayer.jumpToX == graphTime`
    @MainActor var jumpToX: Bool = false
    @MainActor var jumpToY: Bool = false
    
    @MainActor var jumpPositionX: CGFloat = .zero
    @MainActor var jumpPositionY: CGFloat = .zero
            
    // Was the graph recently reset?
    @MainActor var graphReset: Bool = false
    
    @MainActor
    init(rawScrollViewOffset: CGPoint = CGPoint.zero,
         xScrollEnabled: Bool = NativeScrollInteractionNode.defaultScrollXEnabled,
         yScrollEnabled: Bool = NativeScrollInteractionNode.defaultScrollYEnabled,
         contentSize: CGSize = CGSize.zero,
         jumpStyleX: ScrollJumpStyle = ScrollJumpStyle.scrollJumpStyleDefault,
         jumpStyleY: ScrollJumpStyle = ScrollJumpStyle.scrollJumpStyleDefault,
         jumpToX: Bool = false,
         jumpToY: Bool = false,
         jumpPositionX: CGFloat = 0,
         jumpPositionY: CGFloat = 0,
         graphReset: Bool = false) {
        self.rawScrollViewOffset = rawScrollViewOffset
        self.xScrollEnabled = xScrollEnabled
        self.yScrollEnabled = yScrollEnabled
        self.contentSize = contentSize
        self.jumpStyleX = jumpStyleX
        self.jumpStyleY = jumpStyleY
        self.jumpToX = jumpToX
        self.jumpToY = jumpToY
        self.jumpPositionX = jumpPositionX
        self.jumpPositionY = jumpPositionY
        self.graphReset = graphReset
    }
}


extension NativeScrollInteractionLayer {
    // Empty = all scrolling is disabled
    @MainActor
    var scrollAxes: Axis.Set {
        var axes: Axis.Set = []
        
        if xScrollEnabled {
            axes.insert(.horizontal)
        }
        
        if yScrollEnabled {
            axes.insert(.vertical)
        }
        
        return axes
                
//        if yScrollEnabled && xScrollEnabled {
//            return [.vertical, .horizontal]
//        } else if xScrollEnabled {
//            return [.horizontal]
//        } else if yScrollEnabled {
//            return [.vertical]
//        } else {
//            return []
//        }
    }
}
