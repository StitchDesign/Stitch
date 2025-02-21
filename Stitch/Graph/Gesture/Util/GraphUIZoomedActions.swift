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
    func graphZoomedIn(_ manualZoom: GraphManualZoom) {
        // Set `true` here; set `false` by the UIScrollView
        self.graphUI.canvasZoomedIn = manualZoom
        
        // Wipe comment box bounds
        self.wipeCommentBoxBounds()
    }

    @MainActor
    func graphZoomedOut(_ manualZoom: GraphManualZoom) {
        self.graphUI.canvasZoomedOut = manualZoom
        
        // Wipe comment box bounds
        self.wipeCommentBoxBounds()
    }
}
