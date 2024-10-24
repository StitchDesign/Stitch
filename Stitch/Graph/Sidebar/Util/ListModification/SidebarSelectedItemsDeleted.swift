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
    func deleteSelectedItems() {
        self.deleteItems(from: self.selectionState.all)
    }
    
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
        self.graphDelegate?.didItemsDelete(ids: ids)
    }
}

extension GraphState {
    @MainActor
    func didItemsDelete(ids: Set<SidebarListItemId>) {
        ids.forEach {
            self.deleteNode(id: $0)
        }
    }
}
