//
//  NativeScrollInteractionLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/3/24.
//

import SwiftUI

@Observable
final class NativeScrollInteractionLayer: Sendable {

    // Group Node Inputs
    // pulse, e.g. `nativeScrollInteractionLayer.jumpToX == graphTime`
    @MainActor var jumpToX: Bool = false
    @MainActor var jumpToY: Bool = false

    // Group Node Output
    @MainActor var rawScrollViewOffset: CGPoint = .zero
    
    // Graph Reset
    // Was the graph recently reset?
    @MainActor var graphReset: Bool = false
    
    @MainActor
    init(jumpToX: Bool = false,
         jumpToY: Bool = false,
         rawScrollViewOffset: CGPoint = .zero,
         graphReset: Bool = false) {
        self.jumpToX = jumpToX
        self.jumpToY = jumpToY
        self.rawScrollViewOffset = rawScrollViewOffset
        self.graphReset = graphReset
    }
}

