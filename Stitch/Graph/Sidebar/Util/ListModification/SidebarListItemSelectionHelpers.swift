//
//  SidebarListItemSelectionHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/20/24.
//

import StitchSchemaKit
import Foundation
import SwiftUI
import StitchViewKit

extension ProjectSidebarObservable {
    // TODO: finalize this logic; it's not as simple as "the range between last-clicked and just-clicked" nor is it "the range between just-clicked and least-distant-currently-selected"
    //func itemsBetweenClosestSelectedStart(in nestedList: [ListItem],
    func itemsBetweenClosestSelectedStart(in flatList: [Self.ItemViewModel],
                                          clickedItem: Self.ItemViewModel,
                                          lastClickedItem: Self.ItemViewModel,
                                          selections: Set<Self.ItemID>) -> [Self.ItemViewModel]? {
        
        // log("itemsBetweenClosestSelectedStart: flatList map ids: \(flatList.map(\.id))")
        
        let start = lastClickedItem
        
        guard let startIndex = flatList.firstIndex(where: { $0.id == start.id }),
              let clickedItemIndex = flatList.firstIndex(where: { $0.id == clickedItem.id }) else {
            // log("itemsBetweenClosestSelectedStart: could not get index of start item and/or clicked item")
            return nil
        }
        
        // Ensure that start and end are not the same
        guard start.id != clickedItem.id else {
            // log("itemsBetweenClosestSelectedStart: start same as clicked item")
            return nil // If start and end are the same, return nil or handle as needed
        }
        
        let startEarlierThanClickedItem = startIndex < clickedItemIndex
        
        // Determine the range and ensure it includes items regardless of their order
        let range = startEarlierThanClickedItem ? startIndex...clickedItemIndex : clickedItemIndex...startIndex
        //    let range = startIndex < clickedItemIndex ? startIndex...clickedItemIndex : clickedItemIndex...startIndex
        
        // Return the items between start and end (inclusive)
        return Array(flatList[range])
    }

    /*
     Given an unordered set of tapped items,
     Start at top level of the ordered sidebar layers.
     If a group is tapped, then edit-mode-select it and all its descendants.
     If a non-group is tapped, only edit-mode-select it if we do not already do so via some parent’s descendants.

     Iterating through the ordered sidebar layers provides the order and guarantees you don’t hit a child before its parent.
     */
    @MainActor
    func editModeSelectTappedItems(tappedItems: Set<ItemID>) {
        
        // Wipe existing edit mode selections
        self.selectionState.resetEditModeSelections()
        
        self.items.recursiveForEach { sidebarLayer in
            let itemId = sidebarLayer.id
            let wasTapped = tappedItems.contains(itemId)
            
            // Only interested in items that were tapped
            if wasTapped {
                log("editModeSelectTappedItems: sidebarLayer.id \(sidebarLayer.id) was tapped")
                
                self.sidebarItemSelectedViaEditMode(itemId)
            } // if wasTapped
            else {
                log("editModeSelectTappedItems: sidebarLayer.id \(sidebarLayer.id) was NOT tapped")
            }
        } // forEach
    }
    
    func retrieveItem(_ id: Self.ItemID) -> Self.ItemViewModel? {
        self.items.get(id)
    }
}

extension Array where Element: Identifiable {
    // Function to find all items between the smallest and largest consecutive selected items (inclusive)
    // `findItemsBetweenSmallestAndLargestSelected`
    func getIsland(startItem: Element,
                   selections: Set<Element.ID>) -> [Element] {
        let list = self
        
        // Ensure the starting index is within bounds
        guard let startIndex = list.firstIndex(where: { $0.id == startItem.id }),
              startIndex >= 0 && startIndex < list.count else {
            return []
        }
        
        // Check if the starting item is selected
        
        guard let startItem = list[safe: startIndex],
              selections.contains(startItem.id) else {
            log("findItemsBetweenSmallestAndLargestSelected: starting index's item was not atually selected")
            return []
        }
        
        // Initialize variables to store the smallest and largest selected items
        var smallestIndex = startIndex
        var largestIndex = startIndex
        
        // Move backward to find the smallest consecutive selected item
        for i in stride(from: startIndex - 1, through: 0, by: -1) {
            
            if let _i = list[safe: i],
               selections.contains(_i.id) {
                smallestIndex = i
            } else {
                break
            }
        }
        
        // Move forward to find the largest consecutive selected item
        for i in (startIndex + 1)..<list.count {
            if let _i = list[safe: i],
               selections.contains(_i.id) {
                largestIndex = i
            } else {
                break
            }
        }
        
        // Return all items between the smallest and largest indices, inclusive
        let island = Array(list[smallestIndex...largestIndex])
        
        // log("for startItem \(startItem.id), had island \(island.map(\.id))")
        
        return island
    }
}
