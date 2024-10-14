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
    var sidebarIndex: SidebarIndex = .init(groupIndex: .zero, rowIndex: .zero)
    var id: NodeId
    var children: [SidebarItemGestureViewModel]?
    
    var isExpandedInSidebar: Bool?
    
    var dragPosition: CGPoint?
    var prevDragPosition: CGPoint?
    
    // published property to be read in view
    var swipeSetting: SidebarSwipeSetting = .closed

    internal var previousSwipeX: CGFloat = 0
    
    weak var sidebarDelegate: LayersSidebarViewModel?
    weak var parentDelegate: SidebarItemGestureViewModel?

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
    
    func createSchema() -> SidebarLayerData {
        .init(id: self.id,
              children: self.children?.map { $0.createSchema() },
              isExpandedInSidebar: self.isExpandedInSidebar)
    }
    
    func update(from schema: EncodedItemData) {
        self.id = schema.id
        self.isExpandedInSidebar = isExpandedInSidebar
    }
    
    @MainActor var name: String {
        guard let node = self.graphDelegate?.getNodeViewModel(self.id) else {
//            fatalErrorIfDebug()
            return ""
        }
        
        return node.getDisplayTitle()
    }
    
    @MainActor var isVisible: Bool {
        guard let node = self.graphDelegate?.getLayerNode(id: self.id)?.layerNode else {
//            fatalErrorIfDebug()
            return true
        }
            
        return node.hasSidebarVisibility
    }
    
    @MainActor
    func didLabelEdit(to newString: String,
                      isCommitting: Bool) {
        // Treat this is as a "layer inspector edit" ?
        dispatch(NodeTitleEdited(titleEditType: .layerInspector(self.id),
                                 edit: newString,
                                 isCommitting: isCommitting))
    }
    
    func sidebarLayerHovered(itemId: SidebarListItemId) {
        self.graphDelegate?.graphUI.sidebarLayerHovered(layerId: itemId.asLayerNodeId)
    }
    
    func sidebarLayerHoverEnded(itemId: SidebarListItemId) {
        self.graphDelegate?.graphUI.sidebarLayerHoverEnded(layerId: itemId.asLayerNodeId)
    }
    
    @MainActor
    func didDeleteItem() {
        self.graphDelegate?.sidebarItemDeleted(itemId: self.id)
    }
    
    @MainActor
    func didToggleVisibility() {
        dispatch(SidebarItemHiddenStatusToggled(clickedId: self.id))
    }
    
    @MainActor
    func didSelectOnEditMode() {
        dispatch(SidebarItemSelected(id: self.id.asLayerNodeId))
    }
    
    @MainActor
    func didUnselectOnEditMode() {
        dispatch(SidebarItemDeselected(id: self.id))
    }
    
    var isNonEditModeFocused: Bool {
        guard let sidebar = self.sidebarDelegate else { return false }
        return sidebar.inspectorFocusedLayers.focused.contains(self.id)
    }
    
    var isNonEditModeActivelySelected: Bool {
        guard let sidebar = self.sidebarDelegate else { return false }
        return sidebar.inspectorFocusedLayers.activelySelected.contains(self.id)
    }
    
    var isNonEditModeSelected: Bool {
        isNonEditModeFocused || isNonEditModeActivelySelected
    }
    
    var backgroundOpacity: CGFloat {
        if isImplicitlyDragged {
            return 0.5
        } else if (isNonEditModeFocused || isBeingDragged) {
            return (isNonEditModeFocused && !isNonEditModeActivelySelected) ? 0.5 : 1
        } else {
            return 0
        }
    }
    
    var useHalfOpacityBackground: Bool {
        isImplicitlyDragged || (isNonEditModeFocused && !isNonEditModeActivelySelected)
    }
    
    @MainActor
    var isHidden: Bool {
        self.graphDelegate?.getVisibilityStatus(for: self.id) != .visible
    }
    
    @MainActor
    var fontColor: Color {
        guard let selection = self.sidebarDelegate?.selectionState.getSelectionStatus(self.id) else { return .white }
        
#if DEV_DEBUG
        if isHidden {
            return .purple
        }
#endif
        
        // Any 'focused' (doesn't have to be 'actively selected') layer uses white text
        if isNonEditModeSelected {
#if DEV_DEBUG
            return .red
#else
            return .white
#endif
        }
        
#if DEV_DEBUG
        // Easier to see secondary selections for debug
        //        return selection.color(isHidden)
        
        switch selection {
        case .primary:
            return .brown
        case .secondary:
            return .green
        case .none:
            return .blue
        }
        
#endif
        
        if isBeingEdited || isHidden {
            return selection.color(isHidden)
        } else {
            // i.e. if we are not in edit mode, do NOT show secondarily-selected layers (i.e. children of a primarily-selected parent) as gray
            return SIDE_BAR_OPTIONS_TITLE_FONT_COLOR
        }
    }
    
    // TODO: should we only show the arrow icon when we have a sidebar layer immediately above?
    @MainActor
    var masks: Bool {
        guard let graph = self.graphDelegate else { return false }
        
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
        let atleastOneIndexMasks = graph
            .getLayerNode(id: self.id)?
            .layerNode?.masksPort.allLoopedValues
            .contains(where: { $0.getBool ?? false })
        ?? false
        
        return withAnimation {
            atleastOneIndexMasks
        }
    }
    
    @MainActor
    func sidebarItemDeleted(itemId: SidebarListItemId) {
        self.graphDelegate?.sidebarItemDeleted(itemId: itemId)
    }
}
