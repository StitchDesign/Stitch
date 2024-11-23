//
//  LayersSidebarViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/23/24.
//

import SwiftUI

@Observable
final class LayersSidebarViewModel: ProjectSidebarObservable, Sendable {
    typealias EncodedItemData = SidebarLayerData
    
    @MainActor var isEditing = false
    @MainActor var items: [SidebarItemGestureViewModel] = []
    @MainActor var activeSwipeId: NodeId?
    @MainActor var activeGesture: SidebarListActiveGesture<NodeId> = .none
    @MainActor var implicitlyDragged = NodeIdSet()
    @MainActor var currentItemDragged: NodeId?
    
    // Selection state
    @MainActor var haveDuplicated: Bool = false
    @MainActor var optionDragInProgress: Bool = false
    @MainActor var primary = Set<ItemID>()     // items selected because directly clicked
    @MainActor var lastFocused: ItemID?
    
    @MainActor weak var graphDelegate: GraphState?
    
    @MainActor init() { }
}
