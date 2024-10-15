//
//  SidebarListItem.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit

struct SidebarListItem: SidebarItemData, Equatable, Hashable, Identifiable {
    let id: SidebarListItemId
    let layer: LayerNodeTitle
    var location: CGPoint
    var previousLocation: CGPoint

    var zIndex: ZIndex = 1
    var parentId: SidebarListItemId? // has a parent?

    let isGroup: Bool // is a parent for others?

    init(id: SidebarListItemId,
         layer: LayerNodeTitle,
         location: CGPoint,
         parentId: SidebarListItemId? = nil,
         isGroup: Bool) {

        self.id = id
        self.layer = layer
        self.location = location
        self.previousLocation = location
        self.parentId = parentId
        self.isGroup = isGroup
    }

    // use previousLocation, which is not changed during drag,
    // to know the item's indentation before being dragged.
    var indentationLevel: IndentationLevel {
        IndentationLevel.fromXLocation(x: self.previousLocation.x)
    }
}

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

typealias SidebarListItemIds = [SidebarListItemId]

struct SidebarListItemId: Identifiable, Equatable, Hashable, Codable {
    let value: UUID

    init(_ value: UUID) {
        self.value = value
    }

    var id: UUID {
        value
    }

    var asNodeId: NodeId {
        value
    }

    var asLayerNodeId: LayerNodeId {
        LayerNodeId(value)
    }
}
