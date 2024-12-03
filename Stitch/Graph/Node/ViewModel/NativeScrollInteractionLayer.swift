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
    let rawScrollViewOffset: CGPoint
    

    // TODO: DEC 3: Do you need all the inputs of the scroll interaction node here? ... everything
    
    // determines [.vertical, .horizontal] scroll axes for ScrollView
    let scrollX: ScrollMode
    let scrollY: ScrollMode
    
    // custom content size; ignore a dimension if 0
    let contentSize: CGSize
    
    // JUMP
    
    // jump style
    let jumpStyleX: ScrollJumpStyle
    let jumpStyleY: ScrollJumpStyle

    // pulse
    // jump when `.onChange(of: nativeScrollInteractionLayer.jumpToX == graphTime)` is true
    let jumpToX: TimeInterval
    let jumpToY: TimeInterval
    
    let jumpToPositionX: CGFloat
    let jumpToPositionY: CGFloat
    
    // TODO: DEC 3: how to handle graph resets without a graphUISessionId ?
    // maybe `graphTime == 0` triggers a reset?
}

