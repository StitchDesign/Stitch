//
//  NodeRowObserverCachedViewDataExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

// MARK: derived/cached data: PortViewData, ActiveValue, PortColor

extension NodeRowViewModel {   
   @MainActor
   func updateConnectedCanvasItems() {
       self.connectedCanvasItems = self.findConnectedCanvasItems()
       
       // Update port color data
       self.updatePortColor()
   }
}
