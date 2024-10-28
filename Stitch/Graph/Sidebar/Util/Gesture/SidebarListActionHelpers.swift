//
//  CustomListActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/15/22.
//

import Foundation
import SwiftUI

extension ProjectSidebarObservable {
    @MainActor
    static func getMovedtoIndex(firstItemLocation: CGPoint,
                                movingDown: Bool,
                                flattenedItems: [Self.ItemViewModel],
                                // captures max index before dragged elements were removed from list
                                maxRowIndex: Int) -> SidebarIndex? {
        
        let dragAdjustment = Double(CUSTOM_LIST_ITEM_VIEW_HEIGHT) / 2
        let maxGroupIndex = (flattenedItems.max { $0.sidebarIndex.groupIndex < $1.sidebarIndex.groupIndex }?.sidebarIndex.groupIndex ?? 0) + 1
        let dragX = max(firstItemLocation.x, 0)
        let rawFloatX = Int(floor(dragX / Double(CUSTOM_LIST_ITEM_INDENTATION_LEVEL)))
        
        // Note: previous usage of rounding function used inaccurate "movingDown" logic that doesn't apppear any better
        // than a slight dragAdjustment offset
//        let fnRoundingY = movingDown ? ceil : floor
        let dragY = max(firstItemLocation.y, 0)
        let rawFloatY = (dragY + dragAdjustment) / Double(CUSTOM_LIST_ITEM_VIEW_HEIGHT)
        
        let groupIndex = min(Int(rawFloatX), maxGroupIndex)
        let rowIndex = min(Int(rawFloatY), maxRowIndex)
        
        let sidebarIndex = SidebarIndex(groupIndex: groupIndex, rowIndex: rowIndex)
//        log("row index: \(rowIndex)\trawFloatY: \(rawFloatY)")
        
        return sidebarIndex
    }
}
