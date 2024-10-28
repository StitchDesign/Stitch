//
//  LayersSidebarViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/23/24.
//

import SwiftUI

@Observable
final class LayersSidebarViewModel: ProjectSidebarObservable {
    typealias EncodedItemData = SidebarLayerData
    
    var isEditing = false
    var items: [SidebarItemGestureViewModel] = []
    var activeSwipeId: NodeId?
    var activeGesture: SidebarListActiveGesture<NodeId> = .none
    var implicitlyDragged = NodeIdSet()
    var currentItemDragged: NodeId?
    
    // Selection state
    var haveDuplicated: Bool = false
    var optionDragInProgress: Bool = false
    var primary = Set<ItemID>()     // items selected because directly clicked
    var lastFocused: ItemID?
    
    weak var graphDelegate: GraphState?
}
