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
//func findClosestSelectedStart(in nestedList: [[ListItem]],
func findClosestSelectedStart(in flatList: [ListItem],
                              to clickedItem: ListItem,
                              selections: LayerIdSet) -> ListItem? {
    // Flatten the nested list
//    let flatList = nestedList.flatMap { $0 }
    
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

// Function to return all items between the closest selected start and end, ensuring start != end
//func itemsBetweenClosestSelectedStart(in nestedList: [[ListItem]],
func itemsBetweenClosestSelectedStart(in nestedList: [ListItem],
                                      clickedItem: ListItem,
                                      selections: LayerIdSet) -> (newSelections: [ListItem],
                                                                  clickedEarlierThanStart: Bool)? {
    // Flatten the nested list
//    let flatList = nestedList.flatMap { $0 }
//    let flatList: [ListItem] = nestedList.flatMap { $0.children ?? [] }
    let flatList: [ListItem] = nestedList
//    log("itemsBetweenClosestSelectedStart: flatList: \(flatList)")
    log("itemsBetweenClosestSelectedStart: flatList map ids: \(flatList.map(\.id))")
    
    // Find the closest selected start item
    guard let start = findClosestSelectedStart(in: flatList,
                                               to: clickedItem,
                                               selections: selections),
          let startIndex = flatList.firstIndex(of: start),
          let clickedItemIndex = flatList.firstIndex(of: clickedItem) else {
        log("itemsBetweenClosestSelectedStart: no start")
        return nil // Return nil if start or end not found
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

