//
//  GraphUIZoomedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/17/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphZoom {
    // Keep current zoom bound to allowed thresholds
    @MainActor
    static func throttleGraphZoom(zoomAmount: CGFloat, currentScale: CGFloat) -> CGFloat {
        let newScale = currentScale + zoomAmount
        if newScale < 0 || newScale.magnitude < MIN_GRAPH_SCALE {
            // log("throttleGraphZoom: too small: \(newScale)")
            return MIN_GRAPH_SCALE - currentScale
        } else if newScale.magnitude > MAX_GRAPH_SCALE {
            // log("throttleGraphZoom: too big: \(newScale)")
            return MAX_GRAPH_SCALE - currentScale
        }
        return zoomAmount
    }
}

extension StitchDocumentViewModel {
    @MainActor
    func graphPinchToZoom( amount: CGFloat) {
        let graphZoom = self.graphMovement.zoomData

        // Scale zoom based on current device zoom--makes pinch to zoom feel more natural
        var newAmount = (amount - 1) * graphZoom.final
        
        newAmount = GraphZoom.throttleGraphZoom(zoomAmount: newAmount,
                                                currentScale: graphZoom.final)
        
        graphZoom.current = newAmount
    }
    
    @MainActor
    func graphZoomEnded() {
        // set new zoom final to current + final of last zoom state
        self.graphMovement.zoomData.final += self.graphMovement.zoomData.current
        
        if self.graphMovement.zoomData.current != 0 {
            self.graphMovement.zoomData.current = 0
        }

        // Wipe comment box bounds
        self.wipeCommentBoxBounds()
    }

    @MainActor
    func graphZoomedIn(rate: Double = 0.25) {
        self.graphUI.canvasZoomedIn = true
        
        // Wipe comment box bounds
        self.wipeCommentBoxBounds()
    }

    @MainActor
    func graphZoomedOut(rate: Double = 0.25) {
        self.graphUI.canvasZoomedOut = true
        
        // Wipe comment box bounds
        self.wipeCommentBoxBounds()
    }
}
