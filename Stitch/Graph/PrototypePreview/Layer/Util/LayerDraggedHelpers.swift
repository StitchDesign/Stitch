//
//  LayerDraggedHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/14/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// PRESS INTERACTION ON-DRAGGED HELPERS

extension InteractiveLayer {
    // DRAG INTERACTION ON-DRAGGED HELPERS
    @MainActor
    func layerInteracted(translation: CGSize,
                         velocity: CGSize,
                         tapLocation: CGPoint) {
        self.isDown = true
        
        self.dragVelocity = velocity
        self.dragTranslation = translation
        self.lastTappedLocation = tapLocation
        
        if !self.dragStartingPoint.isDefined {
            self.dragStartingPoint = layerPosition
        }
    }
}
