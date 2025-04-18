//
//  SidebarSelectedItemsDeleted.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// MARK: actions on currently selected items

struct SidebarSelectedItemsDeleted: GraphEventWithResponse {
    
    func handle(state: GraphState) -> GraphResponse {
        state.layersSidebarViewModel.deleteSelectedItems()
        return .shouldPersist
    }
}

extension ProjectSidebarObservable {
    @MainActor
    func deleteSelectedItems() {
        self.deleteItems(from: self.selectionState.all)
    }
    
    @MainActor
    func deleteItems(from deletedIds: Set<Self.ItemID>) {
        deletedIds.forEach {
            self.items.remove($0)
        }
        
        self.items.updateSidebarIndices()
        
        self.didItemsDelete(ids: deletedIds)
    }
}

extension LayersSidebarViewModel {
    @MainActor
    func didItemsDelete(ids: Set<SidebarListItemId>) {
        guard let graph = self.graphDelegate,
              let document = self.graphDelegate?.documentDelegate else {
            return
        }
        
        ids.forEach {
            graph.deleteNode(id: $0, document: document)
        }
    }
}
