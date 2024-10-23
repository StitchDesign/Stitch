//
//  SidebarItemSwipable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/23/24.
//

import SwiftUI

extension Array where Element: SidebarItemSwipable {
    /// Helper that recursively travels nested data structure.
    func recursiveForEach(_ callback: @escaping (Element) -> ()) {
        self.forEach { item in
            callback(item)
            
            item.children?.recursiveForEach(callback)
        }
    }
    
    /// Helper that recursively travels nested data structure in DFS traversal (aka children first).
    func recursiveCompactMap(_ callback: @escaping (Element) -> Element?) -> [Element] {
        self.compactMap { item in
            item.children = item.children?.recursiveCompactMap(callback)
            
            return callback(item)
        }
    }
    
    /// Filters out collapsed groups.
    /// List mut be flattened for drag gestures.
    func getVisualFlattenedList() -> [Element] {
        self.flatMap { item in
            if let children = item.children,
               item.isExpandedInSidebar ?? false {
                return [item] + children.getVisualFlattenedList()
            }
            
            return [item]
        }
    }
    
//    /// Helper that recursively travels nested data structure.
//    func recursiveMap<T>(_ callback: @escaping (Element) -> T) -> [T] {
//        self.map { item in
//            let newItem = callback(item)
//            item.children = item.children?.map(callback)
//            return newItem
//        }
//    }
    
    @MainActor
    mutating private func insertDraggedElements(_ elements: [Element],
                                                at index: Int,
                                                shouldPlaceAfter: Bool = true) {
        let insertOffset = shouldPlaceAfter ? 1 : 0
        
        // Logic we want is to insert after the desired element, hence + 1
        self.insert(contentsOf: elements, at: index + insertOffset)
    }
    
    /// Recursive function that traverses nested array until index == 0.
    @MainActor
    func movedDraggedItems(_ draggedItems: [Element],
                           at dragResult: SidebarDragDestination<Element>,
                           dragPositionIndex: SidebarIndex) -> [Element] {
        guard let element = dragResult.element else {
            var newList = self
            newList.insertDraggedElements(draggedItems,
                                          at: 0,
                                          shouldPlaceAfter: false)
            return newList
        }
        
        guard let indexAtHierarchy = self.firstIndex(where: { $0.id == element.id }) else {
            // Recurse children until element found
            return self.map { item in
                item.children = item.children?.movedDraggedItems(draggedItems,
                                                                 at: dragResult,
                                                                 dragPositionIndex: dragPositionIndex)
                return item
            }
        }
        
        var newList = self
        
        switch dragResult {
        case .afterElement(let element):
            newList.insertDraggedElements(draggedItems,
                                          at: indexAtHierarchy,
                                          shouldPlaceAfter: true)
            return newList
        
        case .topOfGroup:
            guard var children = element.children else {
                fatalErrorIfDebug()
                return self
            }
            
            children.insertDraggedElements(draggedItems,
                                           at: 0,
                                           shouldPlaceAfter: false)
            element.children = children
            newList[indexAtHierarchy] = element
            
            return newList
        }
    }
    
    /// Given some made-up location, finds the closest element in a nested sidebar list. Used for item dragging.
    /// Rules:
    ///     * Must match the group index
    ///     * Must ponit to group layer if otherwise top of list
    ///     * Recommended element cannot reside "below" the requested row index.
    @MainActor
    func findClosestElement(draggedElement: Element,
                            to indexOfDraggedLocation: SidebarIndex) -> SidebarDragDestination<Element> {
        let beforeElement = self[safe: indexOfDraggedLocation.rowIndex - 1]
        let afterElement = self[safe: indexOfDraggedLocation.rowIndex]
        
        let supportedGroupRanges = draggedElement
            .supportedGroupRangeOnDrag(beforeElement: beforeElement,
                                       afterElement: afterElement)
        
        // Filters for:
        // 1. Row indices smaller than index--we want all because we could append after a group which is higher up the stack.
        // 2. Rows with allowed groups--which are constrained by the index's above and below element.
        let flattenedItems = self[0..<Swift.max(0, Swift.min(indexOfDraggedLocation.rowIndex, self.count))]
            .filter {
                let thisGroupIndex = $0.sidebarIndex.groupIndex
                return supportedGroupRanges.contains(thisGroupIndex)
            }
        
        // Prioritize correct group hierarchy--if equal use closest row index
        let rankedItems = flattenedItems.sorted { lhs, rhs in
            let lhsGroupIndexDiff = abs(indexOfDraggedLocation.groupIndex - lhs.sidebarIndex.groupIndex)
            let lhsRowIndexDiff = abs(indexOfDraggedLocation.rowIndex - lhs.sidebarIndex.rowIndex)
            
            let rhsGroupIndexDiff = abs(indexOfDraggedLocation.groupIndex - rhs.sidebarIndex.groupIndex)
            let rhsRowIndexDiff = abs(indexOfDraggedLocation.rowIndex - rhs.sidebarIndex.rowIndex)
            
            // Equal groups
            if lhsGroupIndexDiff == rhsGroupIndexDiff {
                return lhsRowIndexDiff < rhsRowIndexDiff
            }

            return lhsGroupIndexDiff < rhsGroupIndexDiff
        }
        
        guard let recommendedItem = rankedItems.first else {
            return .topOfGroup(nil)
        }
        
#if DEV_DEBUG
//        log("recommendation test for \(indexOfDraggedLocation):")
//        rankedItems.forEach { print("\($0.id.debugFriendlyId), \($0.sidebarIndex), diff: \(abs(indexOfDraggedLocation.groupIndex - $0.sidebarIndex.groupIndex))") }
#endif
        
        // Check for condition where we want to insert a row to the top of a group's children list:
        // this returns a different result because elements at top of groups need to be inserted into a group's
        // children property
        if recommendedItem.isGroup && recommendedItem.rowIndex + 1 == indexOfDraggedLocation.rowIndex,
            indexOfDraggedLocation.groupIndex > recommendedItem.sidebarIndex.groupIndex {
            return .topOfGroup(recommendedItem)
        }
        
        return .afterElement(recommendedItem)
    }
}
