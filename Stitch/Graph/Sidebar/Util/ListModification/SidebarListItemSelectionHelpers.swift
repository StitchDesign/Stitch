//
//  SidebarListItemSelectionHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/20/24.
//

import StitchSchemaKit
import Foundation
import SwiftUI

extension ProjectSidebarObservable {
    // Function to find the closest selected item (start point) relative to an end item, excluding the end itself
    func findClosestSelectedStart(in flatList: [Self.EncodedItemData],
                                  to clickedItem: Self.EncodedItemData,
                                  selections: Set<Self.ItemID>) -> Self.EncodedItemData? {
        
        // Find the index of the end item
        guard let clickedItemIndex = flatList.firstIndex(where: { $0.id == clickedItem.id }) else {
            log("findClosestSelectedStart: could not find clickedItemIndex")
            return nil // Return nil if the end item is not found
        }
        
        // Initialize a variable to store the closest selected item
        var closestSelected: Self.EncodedItemData? = nil
        var closestDistance = Int.max
        
        // Search for the closest selected item (before and after the end index)
        for i in 0..<flatList.count {
            let item = flatList[i]
            
            let isSelected = selections.contains(item.id)
            
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
    //func itemsBetweenClosestSelectedStart(in nestedList: [ListItem],
    func itemsBetweenClosestSelectedStart(in flatList: [Self.EncodedItemData],
                                          clickedItem: Self.EncodedItemData,
                                          lastClickedItem: Self.EncodedItemData,
                                          selections: LayerIdSet) -> [Self.EncodedItemData]? {
        
        // log("itemsBetweenClosestSelectedStart: flatList map ids: \(flatList.map(\.id))")
        
        let start = lastClickedItem
        
        guard let startIndex = flatList.firstIndex(of: start),
              let clickedItemIndex = flatList.firstIndex(of: clickedItem) else {
            // log("itemsBetweenClosestSelectedStart: could not get index of start item and/or clicked item")
            return nil
        }
        
        // Ensure that start and end are not the same
        guard start != clickedItem else {
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
}

enum SidebarSelectionExpansionDirection: Equatable {
    case upward, downward, none
}

extension SidebarSelectionExpansionDirection {
    
    static func getExpansionDirection(islandTopIndex: Int,
                                      islandBottomIndex: Int,
                                      lastClickedIndex: Int) -> Self {
        
        // If island top is above last clicked,
        // then we expanded upward
        if islandTopIndex < lastClickedIndex {
            return .upward
        }
        
        // If island bottom is below last clicked,
        // then we expanded downward
        if islandBottomIndex > lastClickedIndex {
            return .downward
        }
        
        return .none
        
    }
}

extension GraphState {
    
    // TODO: combine this with our logic for adding to the current selections
    func shrinkExpansions(flatList: [SidebarLayerData], // ALL items with nesting flattened; used for finding indices
                          itemsBetween: [SidebarLayerData], // the 'range' we clicked; items between last-clicked and just-clicked
                          originalIsland: [SidebarLayerData], // the original contiguous selection range
                          lastClickedItem: SidebarLayerData, // the last-non-shift-clicked item
                          // the just shift-clicked item
                          justClickedItem: SidebarLayerData) {
        
        let newIsland: [SidebarLayerData] = itemsBetween
        
        guard
            let lastClickedIndex = flatList.firstIndex(of: lastClickedItem),
            let justClickedIndex = flatList.firstIndex(of: justClickedItem),
            let originalIslandTop = originalIsland.first,
            let originalIslandBottom = originalIsland.last,
            let originalIslandTopIndex = flatList.firstIndex(of: originalIslandTop),
            let originalIslandBottomIndex = flatList.firstIndex(of: originalIslandBottom) else  {
                log("Could not retrieve requires indices")
                return
        }
        
        let originalExpansionDirection = SidebarSelectionExpansionDirection.getExpansionDirection(
            islandTopIndex: originalIslandTopIndex,
            islandBottomIndex: originalIslandBottomIndex,
            lastClickedIndex: lastClickedIndex)
 
        var shrunk = false
        
        // it's not even as simple as 'expansion directions'
        
        
        // Assuming the case where the island "expands downward", i.e. original island's bottom is below the last clicked,
        // then
        
        // Given that
        // it's more about "is the new clicked below or above
        
        if originalExpansionDirection == .downward {
            
            // If the original island was expanded downward,
            // but the new click range does not extend as far down,
            // then we shrunk:
            if justClickedIndex < originalIslandBottomIndex {
                log("expandOrShrinkExpansions: had expanded downward but new range does not goes as far down")
                shrunk = true
            }
        }
        
        if originalExpansionDirection == .upward {
            // If the original island was expanded upward
            // but the new click range does not extend as far up,
            // then we shrunk:
            if justClickedIndex > originalIslandTopIndex {
                log("expandOrShrinkExpansions: had expanded upward but new range does not goes as far up")
                shrunk = true
            }
        }
        
        log("expandOrShrinkExpansions: shrunk \(shrunk)")
        
        if shrunk {
            // If we shrunk, remove the items that are in the original island but not the new island
            flatList.forEach { item in
                let itemIsInNewIsland = newIsland.contains(item)
                let itemIsInOldIsland = originalIsland.contains(item)
                
                if itemIsInOldIsland
                    && !itemIsInNewIsland
                    && item != lastClickedItem {
                    
                    log("expandOrShrinkExpansions: will remove item \(item)")
                    self.sidebarSelectionState.inspectorFocusedLayers.focused.remove(item.id)
                    self.sidebarSelectionState.inspectorFocusedLayers.activelySelected.remove(item.id)
                }
            }
        }
    }
        
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
        
        self.orderedSidebarLayers.getFlattenedList().forEach { (sidebarLayer: SidebarLayerData) in
            
            let layerId = sidebarLayer.id.asLayerNodeId
            let wasTapped = tappedItems.contains(layerId)
            
            // Only interested in items that were tapped
            if wasTapped {
                log("editModeSelectTappedItems: sidebarLayer.id \(sidebarLayer.id) was tapped")
                
                self.sidebarItemSelectedViaEditMode(layerId,
                                                    isSidebarItemTapped: true)
            } // if wasTapped
            else {
                log("editModeSelectTappedItems: sidebarLayer.id \(sidebarLayer.id) was NOT tapped")
            }
        } // forEach
    }
}


extension SidebarLayerList {
    func getFlattenedList() -> Self {
        flattenListItems(self, acc: .init())
    }
}

func flattenListItems(_ items: [SidebarLayerData],
                      acc: [SidebarLayerData]) -> [SidebarLayerData] {
    var acc = acc
    items.forEach { item in
        acc.append(item)
        let accFromChildren = flattenListItems(item.children ?? [], acc: .init())
        acc += accFromChildren
    }
    return acc
}


// Function to find all items between the smallest and largest consecutive selected items (inclusive)
// `findItemsBetweenSmallestAndLargestSelected`
func getIsland(in list: [SidebarLayerData],
               startItem: SidebarLayerData,
               selections: SidebarListItemIdSet) -> [SidebarLayerData] {
    
    // Ensure the starting index is within bounds
    guard let startIndex = list.firstIndex(where: { $0.id == startItem.id }),
            startIndex >= 0 && startIndex < list.count else {
        return []
    }
    
    // Check if the starting item is selected
    
    guard let startItem = list[safe: startIndex],
          selections.contains(.init(startItem.id)) else {
        log("findItemsBetweenSmallestAndLargestSelected: starting index's item was not atually selected")
        return []
    }
    
    // Initialize variables to store the smallest and largest selected items
    var smallestIndex = startIndex
    var largestIndex = startIndex
    
    // Move backward to find the smallest consecutive selected item
    for i in stride(from: startIndex - 1, through: 0, by: -1) {
        
        if let _i = list[safe: i],
           selections.contains(.init(_i.id)) {
            smallestIndex = i
        } else {
            break
        }
    }
    
    // Move forward to find the largest consecutive selected item
    for i in (startIndex + 1)..<list.count {
        if let _i = list[safe: i],
           selections.contains(.init(_i.id)) {
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
