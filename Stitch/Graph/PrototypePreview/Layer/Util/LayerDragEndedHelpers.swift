//
//  LayerDragEndedHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/14/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension InteractiveLayer {
    @MainActor
    func handleLayerDragEnded() {
        self.dragStartingPoint = nil
        self.isDown = false
        
        // Reset velocity and translation
        self.dragVelocity = .zero
        self.dragTranslation = .zero
        
        // Press node: reset position output
        self.lastTappedLocation = .zero
    }
}

