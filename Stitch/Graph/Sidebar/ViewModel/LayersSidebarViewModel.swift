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
    var selectionState = SidebarSelectionObserver<NodeId>()
    var activeSwipeId: NodeId?
    var activeGesture: SidebarListActiveGesture<NodeId> = .none
    var implicitlyDragged = NodeIdSet()
    var currentItemDragged: NodeId?
    
    weak var graphDelegate: GraphState?
}
