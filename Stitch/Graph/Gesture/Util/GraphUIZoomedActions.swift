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
        let newScale = self.graphMovement.zoomData.final + rate
        if newScale > MAX_GRAPH_SCALE {
            log("GraphZoomedIn: too zoomed in")
            
            if self.graphMovement.zoomData.current != 0 {
                self.graphMovement.zoomData.current = 0
            }
            self.graphMovement.zoomData.final = MAX_GRAPH_SCALE
        } else {
            log("GraphZoomedIn: zoom in okay")
            if self.graphMovement.zoomData.current != 0 {
                self.graphMovement.zoomData.current = 0
            }
            self.graphMovement.zoomData.final = newScale
        }

        // Wipe comment box bounds
        self.wipeCommentBoxBounds()
    }

    @MainActor
    func graphZoomedOut(rate: Double = 0.25) {
        /*
         TODO: finalize this logic, so that we can get max zoom out a without the jump toward the end

         For min scale = 0.1,
         and finalScale is such that subtracting 0.25 will make it either 0 or less than min scale,
         so e.g. 0.36 - 0.25 = 0.11 would be okay
         but 0.34 - 0.25 = 0.9 would be too small.

         Tricky?: if we can't subtract 0.25, then should we subtract 0.10 ?
         With the pinch gesture, we have a smooth continuum; not so for the shortcut.
         */
        let newScale = self.graphMovement.zoomData.final - rate
        let lessThanMinScale = newScale < MIN_GRAPH_SCALE
        let negativeScale = newScale <= 0
        if negativeScale || lessThanMinScale {
            log("GraphZoomedOut: too zoomed out")
            if self.graphMovement.zoomData.current != 0 {
                self.graphMovement.zoomData.current = 0
            }
            self.graphMovement.zoomData.final = MIN_GRAPH_SCALE
        } else {
            log("GraphZoomedOut: zoom out okay")
            if self.graphMovement.zoomData.current != 0 {
                self.graphMovement.zoomData.current = 0
            }
            self.graphMovement.zoomData.final = newScale
        }

        // Wipe comment box bounds
        self.wipeCommentBoxBounds()
    }
}
