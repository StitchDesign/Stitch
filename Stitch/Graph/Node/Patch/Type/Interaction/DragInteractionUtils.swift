//
//  DragInteractionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/14/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let DRAG_NODE_VELOCITY_RESET_STEP: TimeInterval = 0.2

struct DragNodeInputLocations {
    static let layerIndex = 0
    static let isEnabled = 1
    static let isMomentumEnabled = 2
    static let startPoint = 3
    static let reset = 4
    static let clippingEnabled = 5
    static let min = 6
    static let max = 7
    // Position values from layer
    static let layerPositionValues = 9
}

extension PatchNode {
    // TODO: won't work for loops, since only checks first index
    @MainActor
    var isDragNodeEnabled: Bool {
        patch == .dragInteraction &&
            self.inputs[safe: DragNodeInputLocations.isEnabled]?
            .first?.getBool ?? false
    }
}
