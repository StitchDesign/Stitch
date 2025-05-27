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

extension Array where Element: SidebarItemSwipable {
    /// Places an element after the location of some ID.
    @MainActor mutating func remove(_ elementWithId: Element.ID) {
        for (index, item) in self.enumerated() {
            // Remove here if matching case
            if item.id == elementWithId {
                self.remove(at: index)
                
                // Exit recursion on success
                return
            }
            
            // Recursively check children
            item.children?.remove(elementWithId)
            self[index] = item
        }
    }
    
    /// Places an element after the location of some ID.
    @MainActor mutating func remove(_ elementIdSet: Set<Element.ID>) {
        self = self.compactMap { item -> Element? in
            if elementIdSet.contains(item.id) {
                return nil
            }
            
            // Recursively check children
            item.children?.remove(elementIdSet)
            
            return item
        }
    }
}
