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
    // jump when `.onChange(of: nativeScrollInteractionLayer.jumpToX == graphTime)` is true
//    @MainActor var jumpToX: TimeInterval = .zero
    @MainActor var jumpToX: Bool = false
//    @MainActor var jumpToY: TimeInterval = .zero
    @MainActor var jumpToY: Bool = false
    
    @MainActor var jumpPositionX: CGFloat = .zero
    @MainActor var jumpPositionY: CGFloat = .zero
        
    // TODO: DEC 3: how to handle graph resets without a graphUISessionId ?
    // maybe `graphTime == 0` triggers a reset?    
}

extension NativeScrollInteractionLayer {
    // Empty = all scrolling is disabled
    @MainActor
    var scrollAxes: Axis.Set {
        if yScrollEnabled && xScrollEnabled {
            return [.vertical, .horizontal]
        } else if xScrollEnabled {
            return [.horizontal]
        } else if yScrollEnabled {
            return [.vertical]
        } else {
            return []
        }
    }
}
