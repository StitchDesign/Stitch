//
//  scrollAnimation.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 12/15/21.
//

import SwiftUI
import StitchSchemaKit

// MUST BE A FLOAT, since Swift treats `Int / Int` as returning `Int`
let FREE_SCROLL_RUBBERBAND_FRAMERATE: CGFloat = 7

// TODO: rename to `PositionAnimationState` since used by drag interaction node reset as well
struct ScrollAnimationState: Equatable, Codable, Hashable {
    var startValue: CGSize = .zero
    var toValue: CGSize = .zero
    var frameCount: CGFloat = 0

    // for scroll interaction;
    // determined in on-scrolled event handler
    var distance: CGSize = .zero
}
