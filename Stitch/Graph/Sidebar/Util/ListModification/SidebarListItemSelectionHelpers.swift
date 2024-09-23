//
//  SidebarListItemSelectionHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/20/24.
//

import StitchSchemaKit
import Foundation
import SwiftUI

typealias ListItem = SidebarLayerData

// Function to find the closest selected item (start point) relative to an end item, excluding the end itself
func findClosestSelectedStart(in flatList: [ListItem],
                              to clickedItem: ListItem,
                              selections: LayerIdSet) -> ListItem? {
    
    // Find the index of the end item
    guard let clickedItemIndex = flatList.firstIndex(of: clickedItem) else {
        log("findClosestSelectedStart: could not find clickedItemIndex")
        return nil // Return nil if the end item is not found
    }
    
    // Initialize a variable to store the closest selected item
    var closestSelected: ListItem? = nil
    var closestDistance = Int.max
        
    // Search for the closest selected item (before and after the end index)
    for i in 0..<flatList.count {
        let item = flatList[i]
        
        let isSelected = selections.contains(item.id.asLayerNodeId)
        
        if isSelected && item != clickedItem {  // Ensure the selected item is not the same as the end
            
            let distance = abs(i - clickedItemIndex)
            if distance < closestDistance {
                log("findClosestSelectedStart: found closest \(item)")
                closestSelected = item
                closestDistance = distance
            }
        }
    }
    
    log("findClosestSelectedStart: returning closestSelected \(closestSelected)")
    return closestSelected
}

// TODO: finalize this logic; it's not as simple as "the range between last-clicked and just-clicked" nor is it "the range between just-clicked and least-distant-currently-selected"
func itemsBetweenClosestSelectedStart(in nestedList: [ListItem],
                                      clickedItem: ListItem,
                                      lastClickedItem: ListItem,
                                      selections: LayerIdSet) -> (newSelections: [ListItem],
                                                                  clickedEarlierThanStart: Bool)? {
    // Flatten the nested list: the item + its children
    let flatList: [ListItem] = nestedList.flatMap { [$0] + ($0.children ?? []) }
    
    log("itemsBetweenClosestSelectedStart: flatList map ids: \(flatList.map(\.id))")
    
    // Find the closest selected start item
//    guard let start = findClosestSelectedStart(in: flatList,
//                                               from: lastClickedItem,
//                                               to: clickedItem,
//                                               selections: selections),
//          let startIndex = flatList.firstIndex(of: start),
//          let clickedItemIndex = flatList.firstIndex(of: clickedItem) else {
//        log("itemsBetweenClosestSelectedStart: no start")
//        return nil // Return nil if start or end not found
//    }
      
    let start = lastClickedItem
    
    guard let startIndex = flatList.firstIndex(of: start),
          let clickedItemIndex = flatList.firstIndex(of: clickedItem) else {
        log("itemsBetweenClosestSelectedStart: could not get index of start item and/or clicked item")
        return nil
    }
    
    // Ensure that start and end are not the same
    guard start != clickedItem else {
        log("itemsBetweenClosestSelectedStart: start same as clicked item")
        return nil // If start and end are the same, return nil or handle as needed
    }
    
    let startEarlierThanClickedItem = startIndex < clickedItemIndex
    let clickedEarlierThanStart = clickedItemIndex < startIndex
    
    // Determine the range and ensure it includes items regardless of their order
    let range = startEarlierThanClickedItem ? startIndex...clickedItemIndex : clickedItemIndex...startIndex
//    let range = startIndex < clickedItemIndex ? startIndex...clickedItemIndex : clickedItemIndex...startIndex
    
    // Return the items between start and end (inclusive)
    return (newSelections: Array(flatList[range]),
            clickedEarlierThanStart: clickedEarlierThanStart)
}


extension GraphState {
    
    /*
     Given an unordered set of tapped items,
     Start at top level of the ordered sidebar layers.
     If a group is tapped, then edit-mode-select it and all its descendants.
     If a non-group is tapped, only edit-mode-select it if we do not already do so via some parent’s descendants.

     Iterating through the ordered sidebar layers provides the order and guarantees you don’t hit a child before its parent.
     */
    @MainActor
    func editModeSelectTappedItems(tappedItems: LayerIdSet) {
        
        // Wipe existing edit mode selections
        self.sidebarSelectionState.resetEditModeSelections()
        
        self.orderedSidebarLayers.forEach { (sidebarLayer: SidebarLayerData) in
            
            let layerId = sidebarLayer.id.asLayerNodeId
            let wasTapped = tappedItems.contains(layerId)
            
            // Only interested in items that were tapped
            if wasTapped {
                self.sidebarItemSelectedViaEditMode(layerId,
                                                    isSidebarItemTapped: true)
            } // if wasTapped
        } // forEach
    }
}

