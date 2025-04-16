//
//  _SidebarItemGestureViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchViewKit

// MARK: SIDEBAR ITEM SWIPE CONSTANTS

let SWIPE_OPTION_PADDING: CGFloat = 10
let SWIPE_MENU_PADDING: CGFloat = 4

let SWIPE_MENU_OPTION_HITBOX_LENGTH: CGFloat = 30

//let SWIPE_FULL_CORNER_RADIUS: CGFloat = 8
let SWIPE_FULL_CORNER_RADIUS: CGFloat = 4

let RESTING_THRESHOLD: CGFloat = SIDEBAR_WIDTH * 0.2
let RESTING_THRESHOLD_POSITION: CGFloat = SIDEBAR_WIDTH * 0.4
let DEFAULT_ACTION_THRESHOLD: CGFloat = SIDEBAR_WIDTH * 0.75

let GREY_SWIPE_MENU_OPTION_COLOR: Color = Color(.greySwipMenuOption)

let CUSTOM_LIST_ITEM_VIEW_HEIGHT: Int = Int(SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT)
let CUSTOM_LIST_ITEM_INDENTATION_LEVEL: Int = 24

@Observable
final class SidebarItemGestureViewModel: SidebarItemSwipable {
    let id: NodeId
    @MainActor var sidebarIndex: SidebarIndex = .init(groupIndex: .zero, rowIndex: .zero)
    @MainActor var children: [SidebarItemGestureViewModel]?
    
    @MainActor var isExpandedInSidebar: Bool?
    
    @MainActor var dragPosition: CGPoint?
    @MainActor var prevDragPosition: CGPoint?
    
    // published property to be read in view
    @MainActor var swipeSetting: SidebarSwipeSetting = .closed

    @MainActor internal var previousSwipeX: CGFloat = 0
    
    @MainActor var isHovered = false
    
    @MainActor weak var sidebarDelegate: LayersSidebarViewModel?
    
    @MainActor weak var parentDelegate: SidebarItemGestureViewModel? {
        didSet {
            dispatch(AssignedLayerUpdated(changedLayerNode: self.id.asLayerNodeId))
            dispatch(LayerGroupIdChanged(layerNodeId: self.id.asLayerNodeId,
                                         activeIndex: sidebarDelegate?.graphDelegate?.documentDelegate?.activeIndex ?? .init(.zero)))
        }
    }

    @MainActor
    init(data: SidebarLayerData,
         parentDelegate: SidebarItemGestureViewModel?,
         sidebarViewModel: LayersSidebarViewModel) {
        self.id = data.id
        self.isExpandedInSidebar = data.isExpandedInSidebar
        self.parentDelegate = parentDelegate
        self.sidebarDelegate = sidebarViewModel
        
        self.children = data.children?.map {
            SidebarItemGestureViewModel(data: $0,
                                        parentDelegate: self,
                                        sidebarViewModel: sidebarViewModel)
        }
    }
    
    @MainActor
    init(id: NodeViewModel.ID,
         children: [SidebarItemGestureViewModel]?,
         isExpandedInSidebar: Bool?) {
        self.id = id
        self.children = children
        self.isExpandedInSidebar = isExpandedInSidebar
    }
}

extension SidebarItemGestureViewModel {
    static func createId() -> NodeViewModel.ID {
        .init()
    }
    
    @MainActor
    func createSchema() -> SidebarLayerData {
        .init(id: self.id,
              children: self.children?.map { $0.createSchema() },
              isExpandedInSidebar: self.isExpandedInSidebar)
    }
    
    @MainActor
    func update(from schema: EncodedItemData) {
        assertInDebug(self.id == schema.id)
        self.isExpandedInSidebar = isExpandedInSidebar
    }
    
    @MainActor var name: String {
        self.graphDelegate?.getNodeViewModel(self.id)?.getDisplayTitle() ?? ""
    }
    
    @MainActor var layerFullName: String {
        self.graphDelegate?.getNode(self.id)?.kind.getDisplayTitle(customName: "") ?? ""
    }
    
    @MainActor func isVisible(graph: GraphReader) -> Bool {
        guard let node = graph.getLayerNode(self.id) else {
//            fatalErrorIfDebug()
            return true
        }
            
        return node.hasSidebarVisibility
    }
    
    @MainActor
    func didLabelEdit(to newString: String,
                      isCommitting: Bool,
                      graph: GraphState) {
        guard let node = graph.getNodeViewModel(self.id) else {
            fatalErrorIfDebug()
            return
        }
            
        // Treat this is as a "layer inspector edit" ?
        node.nodeTitleEdited(titleEditType: .layerInspector(self.id),
                             edit: newString,
                             isCommitting: isCommitting,
                             graph: graph)
        
        // Recreate the layer drop down choices
        graph.updateLayerDropdownChoiceCache()
    }
    
    @MainActor
    func didDeleteItem() {
        self.graphDelegate?.documentDelegate?.sidebarItemDeleted(itemId: self.id)
    }
    
    @MainActor
    func didToggleVisibility() {
        dispatch(SelectedLayersVisiblityUpdated(selectedLayers: .init([self.id])))
    }
    
    @MainActor
    func didSelectOnEditMode() {
        dispatch(SidebarItemSelected(id: self.id.asLayerNodeId))
    }
    
    @MainActor
    func didUnselectOnEditMode() {
        dispatch(SidebarItemDeselected(id: self.id))
    }
    
    @MainActor
    func isHidden(graph: GraphReader) -> Bool {
        graph.getVisibilityStatus(for: self.id) != .visible
    }
    
    // TODO: should we only show the arrow icon when we have a sidebar layer immediately above?
    @MainActor
    func isMasking(graph: GraphReader) -> Bool {
        
        // TODO: why is this not animated? and why does it jitter?
//        // index of this layer
//        guard let index = graph.sidebarListState.masterList.items
//            .firstIndex(where: { $0.id.asLayerNodeId == nodeId }) else {
//            return withAnimation { false }
//        }
//
//        // hasSidebarLayerImmediatelyAbove
//        guard graph.sidebarListState.masterList.items[safe: index - 1].isDefined else {
//            return withAnimation { false }
//        }
//
        let atleastOneIndexMasks = graph.getLayerNode(self.id)?
            .masksPort
            .allLoopedValues
            .contains(where: { $0.getBool ?? false })
        ?? false
        
        return withAnimation {
            atleastOneIndexMasks
        }
    }
    
    @MainActor
    func sidebarItemDeleted(itemId: SidebarListItemId) {
        self.graphDelegate?.documentDelegate?.sidebarItemDeleted(itemId: itemId)
    }
}
