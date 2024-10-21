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

import StitchViewKit
protocol SidebarItemSwipable: AnyObject, Observable, Identifiable, StitchNestedListElement where Self.ID: Equatable & CustomStringConvertible,
                                                                        SidebarViewModel.ItemViewModel == Self {
    associatedtype SidebarViewModel: ProjectSidebarObservable
//    associatedtype ItemData: ProjectSidebarObservable.ItemData
    typealias ActiveGesture = SidebarListActiveGesture<Self.ID>
    typealias EncodedItemData = SidebarViewModel.EncodedItemData
    
//    var item: ItemData { get set }
    
    var children: [Self]? { get set }
    
    var parentDelegate: Self? { get set }
    
    @MainActor var name: String { get }
    
//    @MainActor var isGroup: Bool { get }
    
//    var parentId: Self.ID? { get set }
    
    // published property to be read in view
    var swipeSetting: SidebarSwipeSetting { get set }

    var previousSwipeX: CGFloat { get set }
    
//    var location: CGPoint { get }
    
//    var previousLocation: CGPoint { get set }
//    var activeGesture: ActiveGesture { get set }
    //    var activeSwipeId: Item.ID? { get set }
    
//    var editOn: Bool { get set }
    
//    var zIndex: Double { get set }
    
    @MainActor var isVisible: Bool { get }
        
    var sidebarIndex: SidebarIndex { get set }
    
    var dragPosition: CGPoint? { get set }

    var prevDragPosition: CGPoint? { get set }
    
    var isExpandedInSidebar: Bool? { get set }
    
    var sidebarDelegate: SidebarViewModel? { get set }
    
    @MainActor var fontColor: Color { get }
    
    var backgroundOpacity: CGFloat { get }
    
    @MainActor var sidebarLeftSideIcon: String { get }
    
    @MainActor var isMasking: Bool { get }
    
    init(data: Self.EncodedItemData,
         parentDelegate: Self?,
         sidebarViewModel: Self.SidebarViewModel)
    
//    @MainActor
//    func sidebarItemTapped(id: Self.ID,
//                           shiftHeld: Bool,
//                           commandHeld: Bool)
//    
//    @MainActor
//    func sidebarListItemDragged(itemId: Self.ID,
//                                translation: CGSize)
//    
//    @MainActor
//    func sidebarListItemDragEnded(itemId: Self.ID)
    
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
    
    @MainActor
    func didLabelEdit(to newString: String, isCommitting: Bool)
    
    @MainActor
    func createSchema() -> SidebarViewModel.EncodedItemData
    
    func update(from schema: Self.EncodedItemData)
}

//extension SidebarItemSwipable {
//    static func == (lhs: Self, rhs: Self) -> Bool {
//        lhs.id == rhs.id &&
//        lhs.zIndex == rhs.zIndex &&
//        lhs.location == rhs.location &&
//        lhs.isExpandedInSidebar == rhs.isExpandedInSidebar &&
//        lhs.parentId == rhs.parentId
//    }
//}

extension SidebarItemSwipable {
    var zIndex: Double {
        if self.activeGesture.isDrag {
            return SIDEBAR_ITEM_MAX_Z_INDEX
        }
        
        return 0
    }
    
    @MainActor
    var isGroup: Bool {
        self.children.isDefined
    }
    
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
    
    @MainActor
    var location: CGPoint {
        let index = self.sidebarIndex
        return .init(x: CUSTOM_LIST_ITEM_INDENTATION_LEVEL * index.groupIndex,
                     y: Self.inferLocationY(from: index.rowIndex))
    }
    
    static func inferLocationY(from rowIndex: Int) -> Int {
        CUSTOM_LIST_ITEM_VIEW_HEIGHT * rowIndex
    }
    
    var isImplicitlyDragged: Bool {
        self.sidebarDelegate?.implicitlyDragged.contains(id) ?? false
    }
    
    var isBeingDragged: Bool {
        self.sidebarDelegate?.currentItemDragged == self.id
    }
    
    var isCollapsedGroup: Bool {
        !(self.isExpandedInSidebar ?? true)
    }
    
    // MARK: GESTURE HANDLERS

    @MainActor
    var onItemDragChanged: OnItemDragChangedHandler {
        return { (translation: CGSize) in
            
            if self.activeGesture != .dragging(self.id) {
//                log("SidebarItemGestureViewModel: itemDragChangedGesture called on \(self.id.description)")
                self.activeGesture = .dragging(self.id)
            }
            
            // Needs to be dispatched due to simultaneous access errors with view
            Task { @MainActor [weak self] in
                guard let item = self else { return }
                
                item.sidebarDelegate?.sidebarListItemDragged(
                    item: item,
                    translation: translation)
            }
        }
    }

    @MainActor
    var onItemDragEnded: OnDragEndedHandler {
        return {
            // print("SidebarItemGestureViewModel: itemDragEndedGesture called")
            guard self.activeGesture != .none else { return }
                
            if self.activeGesture != .none {
                self.activeGesture = .none
            }
            
            self.sidebarDelegate?.sidebarListItemDragEnded()
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
            if self.activeGesture != .dragging(self.id) {
                log("SidebarItemGestureViewModel: longPressDragGesture: longPress onChanged")
                self.activeGesture = .dragging(self.id)
            }
    
            self.sidebarDelegate?.sidebarListItemLongPressed(itemId: self.id)
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
                if self.activeGesture != .swiping {
                    self.activeGesture = .swiping
                }
            }
            if self.activeGesture.isSwipe {
                //                print("SidebarItemGestureViewModel: itemSwipeChangedGesture: updating per swipe")
                // never let us drag the list eastward beyond its frame
                let newSwipeX = max(self.previousSwipeX - translationWidth, 0)
                self.swipeSetting = .swiping(newSwipeX)

                if self.activeSwipeId != self.id {
                    self.activeSwipeId = self.id
                }
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
                
                if self.activeGesture != .none {
                    self.activeGesture = .none
                }
                
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
    
    var graphDelegate: GraphState? {
        self.sidebarDelegate?.graphDelegate
    }
}

@Observable
final class SidebarItemGestureViewModel: SidebarItemSwipable {
    var sidebarIndex: SidebarIndex = .init(groupIndex: .zero, rowIndex: .zero)
    var id: NodeId
    var children: [SidebarItemGestureViewModel]?
//    var location: CGPoint
//    var previousLocation: CGPoint
//    var parentId: NodeId?
//    var zIndex: Double = .zero
    
    var isExpandedInSidebar: Bool?
    
    var dragPosition: CGPoint?
    var prevDragPosition: CGPoint?
    
    // published property to be read in view
    var swipeSetting: SidebarSwipeSetting = .closed

    internal var previousSwipeX: CGFloat = 0
    
    weak var sidebarDelegate: LayersSidebarViewModel?
    
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
    
    weak var parentDelegate: SidebarItemGestureViewModel?

    init(data: SidebarLayerData,
         parentDelegate: SidebarItemGestureViewModel?,
         sidebarViewModel: LayersSidebarViewModel) {
        self.id = data.id
        self.isExpandedInSidebar = data.isExpandedInSidebar
//        self.location = location
        self.parentDelegate = parentDelegate
//        self.previousLocation = location
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
    
    static func createId() -> NodeViewModel.ID {
        .init()
    }
}

extension Array where Element: SidebarItemSwipable {
    var flattenedItems: [Element] {
        self.flatMap { item in
            var items = [item]
            items += item.children?.flattenedItems ?? []
            return items
        }
    }
    
    func updateSidebarIndices() {
        var currentRowIndex = 0
        return self.updateSidebarIndices(currentGroupIndex: 0,
                                         currentRowIndex: &currentRowIndex)
    }
    
    private func updateSidebarIndices(currentGroupIndex: Int,
                                      currentRowIndex: inout Int,
                                      parent: Element? = nil) {
        for item in self {
            let newIndex = SidebarIndex(groupIndex: currentGroupIndex,
                                        rowIndex: currentRowIndex)
            
            // Saves render cycles
            if newIndex != item.sidebarIndex {
                item.sidebarIndex = newIndex
            }
            
            if item.parentDelegate?.id != parent?.id {
                item.parentDelegate = parent
            }
            
            currentRowIndex += 1
            
            if let children = item.children,
               item.isExpandedInSidebar ?? false {
                children
                    .updateSidebarIndices(currentGroupIndex: currentGroupIndex + 1,
                                          currentRowIndex: &currentRowIndex,
                                          parent: item)
            }
        }
    }
}

struct SidebarIndex: Equatable {
    let groupIndex: Int // horizontal
    let rowIndex: Int   // vertical
}

extension SidebarItemSwipable {
    var parentId: Self.ID? {
        self.parentDelegate?.id
    }
    
    var rowIndex: Int {
        guard let sidebar = self.sidebarDelegate else {
            fatalErrorIfDebug()
            return -1
        }
        
        let flattenedItems = sidebar.items.flattenedItems
        guard let index = flattenedItems.enumerated().first(where: { $0.1.id == self.id })?.0 else {
            fatalErrorIfDebug()
            return -1
        }
        
        return index
    }
    
//    @MainActor
//    func getSidebarIndex() -> SidebarIndex {
//        guard let index = self.sidebarDelegate?.items.getSidebarIndex(for: self.id) else {
//            fatalErrorIfDebug()
//            return .init(groupIndex: -1,
//                         rowIndex: -1)
//        }
//        
//        return index
//    }
}

extension SidebarItemGestureViewModel {
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
    
//    @MainActor
//    var parentId: SidebarListItemId? {
//        guard let layerNode = self.graphDelegate?.getNodeViewModel(self.id)?.layerNode else {
//            return nil
//        }
//        
//        return .init(layerNode.layerGroupId)
//    }
    
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
        dispatch(SidebarItemHiddenStatusToggled(clickedId: self.id.asLayerNodeId))
    }
    
    @MainActor
    func didSelectOnEditMode() {
        dispatch(SidebarItemSelected(id: self.id.asLayerNodeId))
    }
    
    @MainActor
    func didUnselectOnEditMode() {
        dispatch(SidebarItemDeselected(id: self.id))
    }
    
//    var layerNodeId: LayerNodeId {
//        self.id.asLayerNodeId
//    }
    
//    var location: CGPoint {
//        self.item.location
//    }
    
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
    
//    @MainActor
//    func sidebarListItemDragged(itemId: SidebarListItemId,
//                                translation: CGSize) {
//        self.graphDelegate?.sidebarListItemDragged(itemId: itemId,
//                                                   translation: translation)
//    }
//    
//    @MainActor
//    func sidebarListItemDragEnded(itemId: SidebarListItemId) {
//        self.graphDelegate?.sidebarListItemDragEnded(itemId: itemId)
//    }
    
//    @MainActor
//    func sidebarListItemLongPressed(id: SidebarListItemId) {
//        self.graphDelegate?.sidebarListItemLongPressed(id: id)
//    }
    
    @MainActor
    func sidebarItemDeleted(itemId: SidebarListItemId) {
        self.graphDelegate?.sidebarItemDeleted(itemId: itemId)
    }
    
//    @MainActor
//    func sidebarItemTapped(id: SidebarItemGestureViewModel.ID,
//                           shiftHeld: Bool,
//                           commandHeld: Bool) {
//        dispatch(SidebarItemTapped(id: id.asLayerNodeId,
//                                   shiftHeld: shiftHeld,
//                                   commandHeld: commandHeld))
//    }
}
