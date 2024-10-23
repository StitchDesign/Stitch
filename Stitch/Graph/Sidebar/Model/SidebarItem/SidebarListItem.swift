//
//  SidebarListItem.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit

extension Identifiable {
    // this item's index
    func itemIndex(_ items: [Self]) -> Int {
        guard let index = items.firstIndex(where: { $0.id == self.id }) else {
            fatalErrorIfDebug()
            return -1
        }
        
        return index
    }
}

typealias SidebarListItemId = NodeId

typealias SidebarListItemIds = [SidebarListItemId]

struct SidebarIndex: Equatable {
    let groupIndex: Int // horizontal
    let rowIndex: Int   // vertical
}
