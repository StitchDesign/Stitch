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
       self.connectedCanvasItems = self.getConnectedCanvasItems()
       
       // Update port color data
       self.updatePortColor()
   }
   
   /// Nodes connected via edge.
   @MainActor
   private func getConnectedCanvasItems() -> Set<CanvasItemId> {
       guard let canvasIds = self.rowDelegate?.nodeDelegate?
        .getAllCanvasObservers()
        .map({ canvasItem in
            canvasItem.id
        }).toSet else {
           // Valid nil case for insert node menu
           return .init()
       }
       
       // Must get port UI data. Helpers below will get group or splitter data depending on focused group
       let connectedCanvasIds = self.findConnectedCanvasItems()
       return canvasIds.union(connectedCanvasIds)
   }
}

