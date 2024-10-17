//
//  CustomListData.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/15/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// // MARK: DATA

//struct SidebarListState {
//    var masterList: SidebarListItemsCoordinator
//    var current: SidebarDraggedItem?
//    var proposedGroup: ProposedGroup?
//    var cursorDrag: SidebarCursorHorizontalDrag?
//
//    // empty initialization
//    init(_ masterList: MasterList = MasterList([]),
//         _ current: SidebarDraggedItem? = nil,
//         _ proposedGroup: ProposedGroup? = nil,
//         _ cursorDrag: SidebarCursorHorizontalDrag? = nil) {
//        self.masterList = masterList
//        self.current = current
//        self.proposedGroup = proposedGroup
//        self.cursorDrag = cursorDrag
//    }
//}

// if nil, then the 'proposed group' is top level
// and xIdentation = 0
struct ProposedGroup<ItemId> {

    let parentId: ItemId
    let xIndentation: CGFloat

    var indentationLevel: IndentationLevel {
        IndentationLevel.fromXLocation(x: xIndentation)
    }
}

struct IndentationLevel: Equatable {
    let value: Int

    init(_ value: Int) {
        self.value = value
    }

    func inc() -> IndentationLevel {
        IndentationLevel(self.value + 1)
    }

    func dec() -> IndentationLevel {
        IndentationLevel(self.value - 1)
    }

    static func fromXLocation(x: CGFloat) -> IndentationLevel {
        IndentationLevel(Int(x / CGFloat(CUSTOM_LIST_ITEM_INDENTATION_LEVEL)))
    }

    var toXLocation: CGFloat {
        CGFloat(self.value * CUSTOM_LIST_ITEM_INDENTATION_LEVEL)
    }
}

struct SidebarDraggedItem<ItemID: Hashable> {
    // directly dragged
    var current: ItemID

    // layers dragged along as part of children or which were otherwise explcitly-selected etc.
    var draggedAlong: Set<ItemID>
}

//typealias SidebarListItems = [SidebarListItem]

// parentId: [children in order]
//typealias ExcludedGroupsData<ItemViewModel: SidebarItemSwipable> = [ItemViewModel.ID: [ItemViewModel]]
typealias SidebarListItemIdSet = Set<SidebarListItemId>
//typealias CollapsedGroups = SidebarListItemIdSet

// TODO: better name or abstraction here?
//struct SidebarListItemsCoordinator: Codable, Equatable, Hashable {
//    var items: SidebarListItems
//    // the [parentId: child-ids] that are not currently shown
//    var excludedGroups: ExcludedGroups
//
//    // groups currently opened or closed;
//    // an item's id is added when its group closed,
//    // removed when its group opened;
//    // NOTE: a supergroup parent closing/opening does NOT affect a subgroup's closed/open status
//    var collapsedGroups: SidebarListItemIdSet
//
//    init(_ items: SidebarListItems,
//         _ excludedGroups: ExcludedGroups = ExcludedGroups(),
//         _ collapsedGroups: SidebarListItemIdSet = SidebarListItemIdSet()) {
//        self.items = items
//        self.excludedGroups = excludedGroups
//        self.collapsedGroups = collapsedGroups
//    }
//}

extension ProjectSidebarObservable {
    @MainActor
    func appendToExcludedGroup(for key: Self.ItemID,
                               _ newItem: Self.ItemViewModel) {
        self.appendToExcludedGroup(
            for: key,
            [newItem],
            self.excludedGroups)
    }
}

// `SidebarCursorDrag` represents the current position
// of user's cursor during a sidebar-list-item drag operation.
// We must keep track of the gesture's x-translation
// without changing the x-position of the being-dragged-item
// (which is controlled by `snapDescendants`).
struct SidebarCursorHorizontalDrag<ItemViewModel> where ItemViewModel: SidebarItemSwipable {
    var x: CGFloat
    var previousX: CGFloat

    // called at start of a drag gesture
    @MainActor
    static func fromItem(_ item: ItemViewModel) -> Self {
        SidebarCursorHorizontalDrag(x: item.location.x,
                                    previousX: item.previousLocation.x)
    }
}
