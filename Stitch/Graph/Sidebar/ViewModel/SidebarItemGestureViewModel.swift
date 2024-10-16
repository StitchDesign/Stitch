//
//  _SidebarItemGestureViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI

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

//protocol SidebarItemData: Identifiable, Equatable where Self.ID: Equatable {
////    var parentId: Self.ID? { get set }
////    var location: CGPoint { get set }
//}

protocol SidebarItemSwipable: AnyObject, Observable, Identifiable where Self.ID: Equatable,
                                                                        SidebarViewModel.ItemViewModel == Self {
    associatedtype SidebarViewModel: ProjectSidebarObservable
//    associatedtype ItemData: ProjectSidebarObservable.ItemData
    typealias ActiveGesture = SidebarListActiveGesture<Self.ID>
    
//    var item: ItemData { get set }
    
    var name: String { get set }
    
    var isGroup: Bool { get }
    
    var parentId: Self.ID { get set }
    
    // published property to be read in view
    var swipeSetting: SidebarSwipeSetting { get set }

    var previousSwipeX: CGFloat { get set }
    
    var location: CGPoint { get set }
    
    var previousLocation: CGPoint { get set }
//    var activeGesture: ActiveGesture { get set }
    //    var activeSwipeId: Item.ID? { get set }
    
//    var editOn: Bool { get set }
    
    var zIndex: Double { get set }
    
    var isExpandedInSidebar: Bool? { get set }
    
    var sidebarDelegate: SidebarViewModel? { get }
    
    var fontColor: Color { get }
    
    var backgroundOpacity: CGFloat { get }
    
    @MainActor
    func sidebarItemTapped(id: Self.ID,
                           shiftHeld: Bool,
                           commandHeld: Bool)
    
    @MainActor
    func sidebarListItemDragged(itemId: Self.ID,
                                translation: CGSize)
    
    @MainActor
    func sidebarListItemDragEnded(itemId: Self.ID)
    
//    @MainActor
//    func sidebarListItemLongPressed(id: Item.ID)
    
    @MainActor
    func sidebarItemDeleted(itemId: Self.ID)
    
    @MainActor
    func contextMenuInteraction(itemId: Self.ID,
                                graph: GraphState,
                                keyboardObserver: KeyboardObserver) -> UIContextMenuConfiguration?
    
    @MainActor
    func sidebarLayerHovered(itemId: Self.ID)
    
    @MainActor
    func sidebarLayerHoverEnded(itemId: Self.ID)
    
    @MainActor
    func didSelectOnEditMode()
    
    @MainActor
    func didUnselectOnEditMode()
    
    @MainActor
    func didDeleteItem()
    
    @MainActor
    func didToggleVisibility()
}

extension SidebarItemSwipable: Identifiable {
    var activeGesture: SidebarListActiveGesture<Self.ID> {
        get {
            self.sidebarDelegate?.activeGesture ?? .none
        }
        set(newValue) {
            self.sidebarDelegate?.activeGesture = newValue
        }
    }
    
    var activeSwipeId: Self.ID? {
        get {
            self.sidebarDelegate?.activeSwipeId ?? nil
        }
        set(newValue) {
            self.sidebarDelegate?.activeSwipeId = newValue
        }
    }
    
    var isBeingEdited: Bool {
        self.sidebarDelegate?.isEditing ?? false
    }
    
//    var location: CGPoint {
//        get {
//            self.item.location
//        }
//        set(newValue) {
//            self.item.location = newValue
//        }
//    }
    
    var isImplicitlyDragged: Bool {
        self.sidebarDelegate?.implicitlyDragged.contains(id) ?? false
    }
    
    var isBeingDragged: Bool {
        self.sidebarDelegate?.currentItemDragged != nil
    }
    
    // MARK: GESTURE HANDLERS

    @MainActor
    var onItemDragChanged: OnItemDragChangedHandler {
        return { (translation: CGSize) in
            // print("SidebarItemGestureViewModel: itemDragChangedGesture called")
            self.activeGesture = .dragging(self.id)
            self.sidebarListItemDragged(
                itemId: self.id,
                translation: translation)
        }
    }

    @MainActor
    var onItemDragEnded: OnDragEndedHandler {
        return {
            // print("SidebarItemGestureViewModel: itemDragEndedGesture called")
            if self.activeGesture == .none {
                // print("SidebarItemGestureViewModel: onItemDragEnded: no active gesture, so will do nothing")
                self.activeGesture = .none
            } else {
                self.activeGesture = .none
                self.sidebarListItemDragEnded(itemId: self.id)
            }
        }
    }

    @MainActor
    var macDragGesture: DragGestureTypeSignature {

        // print("SidebarItemGestureViewModel: macDragGesture: called")
        
//        let itemDrag = DragGesture(minimumDistance: 0)
        // Use a tiny min-distance so that we can distinguish between a tap vs a drag
        let itemDrag = DragGesture(minimumDistance: 5)
            .onChanged { value in
                // print("SidebarItemGestureViewModel: macDragGesture: itemDrag onChanged")
                self.onItemDragChanged(value.translation)
            }.onEnded { _ in
                // print("SidebarItemGestureViewModel: macDragGesture: itemDrag onEnded")
                self.onItemDragEnded()
            }

        return itemDrag
    }
    
    @MainActor
    var longPressDragGesture: LongPressAndDragGestureType {

        let longPress = LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            print("SidebarItemGestureViewModel: longPressDragGesture: longPress onChanged")
            self.activeGesture = .dragging(self.id)
            self.sidebarDelegate?.sidebarListItemLongPressed(id: self.id)
        }

        // TODO: Does `minimumDistance` matter?
//        let itemDrag = DragGesture(minimumDistance: 0)
        let itemDrag = DragGesture(minimumDistance: 5)
            .onChanged { value in
                print("SidebarItemGestureViewModel: longPressDragGesture: itemDrag onChanged")
                self.onItemDragChanged(value.translation)
            }.onEnded { _ in
                print("SidebarItemGestureViewModel: longPressDragGesture: itemDrag onEnded")
                self.onItemDragEnded()
            }

        return longPress.sequenced(before: itemDrag)
    }

    var onItemSwipeChanged: OnDragChangedHandler {
        let onSwipeChanged: OnDragChangedHandler = { (translationWidth: CGFloat) in
            if self.isBeingEdited {
                //                print("SidebarItemGestureViewModel: itemSwipeChangedGesture: currently in edit mode, so cannot swipe")
                return
            }
            // if we have no active gesture,
            // and we met the swipe threshold,
            // then we can begin swiping
            if self.activeGesture.isNone
                && translationWidth.magnitude > SIDEBAR_ACTIVE_GESTURE_SWIPE_THRESHOLD {
                //                print("SidebarItemGestureViewModel: itemSwipeChangedGesture: setting us to swipe")
                self.activeGesture = .swiping
            }
            if self.activeGesture.isSwipe {
                //                print("SidebarItemGestureViewModel: itemSwipeChangedGesture: updating per swipe")
                // never let us drag the list eastward beyond its frame
                let newSwipeX = max(self.previousSwipeX - translationWidth, 0)
                self.swipeSetting = .swiping(newSwipeX)

                self.activeSwipeId = self.id
            }
        }

        return onSwipeChanged
    }

    // not redefined when a passed in redux value changes?
    // unless we make a function?
    @MainActor
    var onItemSwipeEnded: OnDragEndedHandler {
        let onSwipeEnded: OnDragEndedHandler = {
            //            print("SidebarItemGestureViewModel: itemSwipeEndedGesture called")

            if self.isBeingEdited {
                //                print("SidebarItemGestureViewModel: itemSwipeEndedGesture: currently in edit mode, so cannot swipe")
                return
            }

            // if we had been swiping, then we reset activeGesture
            if self.activeGesture.isSwipe {
                //                print("SidebarItemGestureViewModel: itemSwipeEndedGesture onEnded: resetting swipe")
                self.activeGesture = .none
                if self.atDefaultActionThreshold {
                    // Don't need to change x position here,
                    // since redOption's offset handles that.
                    self.sidebarItemDeleted(itemId: self.id)
                } else if self.hasCrossedRestingThreshold {
                    self.swipeSetting = .open
                }
                // we didn't pull it out far enough -- set x = 0
                else {
                    self.swipeSetting = .closed
                }
                self.previousSwipeX = self.swipeSetting.distance
                self.activeSwipeId = self.id
            } // if active...
        }
        return onSwipeEnded
    }

    // MARK: SWIPE LOGIC

    func resetSwipePosition() {
        swipeSetting = .closed
        previousSwipeX = 0
    }

    var atDefaultActionThreshold: Bool {
        swipeSetting.distance >= DEFAULT_ACTION_THRESHOLD
    }

    var hasCrossedRestingThreshold: Bool {
        swipeSetting.distance >= RESTING_THRESHOLD
    }
}

@Observable
final class SidebarItemGestureViewModel: SidebarItemSwipable {
    var item: SidebarListItem
    var location: CGPoint
    var previousLocation: CGPoint
    
    // published property to be read in view
    var swipeSetting: SidebarSwipeSetting = .closed

    internal var previousSwipeX: CGFloat = 0
    
    weak var sidebarDelegate: LayersSidebarViewModel?
    weak var graphDelegate: GraphState?
    
//    @Binding var activeGesture: SidebarListActiveGesture<SidebarListItem.ID> {
//        didSet {
//            switch activeGesture {
//            // scrolling or dragging resets swipe-menu
//            case .scrolling, .dragging:
//                resetSwipePosition()
//            default:
//                return
//            }
//        }
//    }

    // Tracks if the edit menu is open
    var isBeingEdited: Bool = false
//    @Binding var activeSwipeId: SidebarListItemId?

    init(item: SidebarListItem,
         location: CGPoint,
         sidebarViewModel: LayersSidebarViewModel,
         graph: GraphState) {
        self.item = item
        self.location = location
        self.previousLocation = location
        self.sidebarDelegate = sidebarViewModel
        self.graphDelegate = graph
    }
}

extension SidebarItemGestureViewModel {
    var name: String {
        guard let node = self.graphDelegate?.getNodeViewModel(item.id.asNodeId) else {
            fatalErrorIfDebug()
            return ""
        }
        
        return node.getDisplayTitle()
    }
    
    var isVisible: Bool {
        guard let node = graph.getLayerNode(id: itemViewModel.id)?.layerNode else {
            fatalErrorIfDebug()
            return true
        }
            
        return node.hasSidebarVisibility
    }
    
    var id: SidebarListItemId {
        self.item.id
    }
    
    @MainActor
    var isGroup: Bool {
        guard let layerNode = self.graphDelegate?.getNodeViewModel(self.id.asNodeId)?.layerNode else {
            return false
        }
        
        return layerNode.layer == .group
    }
    
    func sidebarLayerHovered(itemId: SidebarListItemId) {
        self.graphDelegate?.graphUI.sidebarLayerHovered(layerId: itemId.asLayerNodeId)
    }
    
    func sidebarLayerHoverEnded(itemId: SidebarListItemId) {
        self.graphDelegate?.graphUI.sidebarLayerHoverEnded(layerId: itemId.asLayerNodeId)
    }
    
    @MainActor
    func didDeleteItem() {
        self.graphDelegate?.sidebarItemDeleted(itemId: self.item.id)
    }
    
    @MainActor
    func didToggleVisibility() {
        dispatch(SidebarItemHiddenStatusToggled(clickedId: self.item.id.asLayerNodeId))
    }
    
    @MainActor
    func didSelectOnEditMode() {
        dispatch(SidebarItemSelected(id: self.item.id.asLayerNodeId))
    }
    
    @MainActor
    func didUnselectOnEditMode() {
        dispatch(SidebarItemDeselected(id: self.item.id.asLayerNodeId))
    }
    
    var layerNodeId: LayerNodeId {
        item.id.asLayerNodeId
    }
    
//    var location: CGPoint {
//        self.item.location
//    }
    
    var isNonEditModeFocused: Bool {
        guard let sidebar = self.sidebarDelegate else { return false }
        return sidebar.inspectorFocusedLayers.focused.contains(layerNodeId)
    }
    
    var isNonEditModeActivelySelected: Bool {
        guard let sidebar = self.sidebarDelegate else { return false }
        return sidebar.inspectorFocusedLayers.activelySelected.contains(layerNodeId)
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
        self.graphDelegate?.getVisibilityStatus(for: item.id.asNodeId) != .visible
    }
    
    @MainActor
    var fontColor: Color {
        guard let graph = self.graphDelegate else { return .white }
        
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
            .getLayerNode(id: self.item.id.asNodeId)?
            .layerNode?.masksPort.allLoopedValues
            .contains(where: { $0.getBool ?? false })
        ?? false
        
        return withAnimation {
            atleastOneIndexMasks
        }
    }
    
    @MainActor
    func sidebarListItemDragged(itemId: SidebarListItemId,
                                translation: CGSize) {
        self.graphDelegate?.sidebarListItemDragged(itemId: itemId,
                                                   translation: translation)
    }
    
    @MainActor
    func sidebarListItemDragEnded(itemId: SidebarListItemId) {
        self.graphDelegate?.sidebarListItemDragEnded(itemId: itemId)
    }
    
//    @MainActor
//    func sidebarListItemLongPressed(id: SidebarListItemId) {
//        self.graphDelegate?.sidebarListItemLongPressed(id: id)
//    }
    
    @MainActor
    func sidebarItemDeleted(itemId: SidebarListItemId) {
        self.graphDelegate?.sidebarItemDeleted(itemId: itemId)
    }
    
    
    @MainActor
    func sidebarItemTapped(id: SidebarItemGestureViewModel.Item.ID,
                           shiftHeld: Bool,
                           commandHeld: Bool) {
        dispatch(SidebarItemTapped(id: id.asLayerNodeId,
                                   shiftHeld: shiftHeld,
                                   commandHeld: commandHeld))
    }
}
