//
//  GraphUIZoomedActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/17/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

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
