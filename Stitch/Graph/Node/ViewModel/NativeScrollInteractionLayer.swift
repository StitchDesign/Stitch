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
    @MainActor var scrollX: ScrollMode = .scrollModeDefault
    @MainActor var scrollY: ScrollMode = .scrollModeDefault
    
    // custom content size; ignore a dimension if 0
    @MainActor var contentSize: CGSize = .zero
    
    // JUMP
    
    // jump style
    @MainActor var jumpStyleX: ScrollJumpStyle = .scrollJumpStyleDefault
    @MainActor var jumpStyleY: ScrollJumpStyle = .scrollJumpStyleDefault

    // pulse
    // jump when `.onChange(of: nativeScrollInteractionLayer.jumpToX == graphTime)` is true
    @MainActor var jumpToX: TimeInterval = .zero
    @MainActor var jumpToY: TimeInterval = .zero
    
    @MainActor var jumpToPositionX: CGFloat = .zero
    @MainActor var jumpToPositionY: CGFloat = .zero
    
    // TODO: DEC 3: how to handle graph resets without a graphUISessionId ?
    // maybe `graphTime == 0` triggers a reset?    
}

