//
//  SidebarItemSwipable.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 10/23/24.
//

import SwiftUI
import StitchViewKit

protocol SidebarItemSwipable: AnyObject, Observable, Identifiable, StitchNestedListElement where Self.ID: Equatable & CustomStringConvertible,
                                                                        SidebarViewModel.ItemViewModel == Self {
    associatedtype SidebarViewModel: ProjectSidebarObservable
    typealias ActiveGesture = SidebarListActiveGesture<Self.ID>
    typealias EncodedItemData = SidebarViewModel.EncodedItemData
    
    var children: [Self]? { get set }
    
    var parentDelegate: Self? { get set }
    
    @MainActor var name: String { get }

    var swipeSetting: SidebarSwipeSetting { get set }

    var previousSwipeX: CGFloat { get set }
    
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

extension SidebarItemSwipable {
    var zIndex: Double {
        if self.isBeingDragged {
            return SIDEBAR_ITEM_MAX_Z_INDEX
        }
        
        return 0
    }
    
    @MainActor
    var isGroup: Bool {
        self.children.isDefined
    }
    
    @MainActor
    func supportedGroupRangeOnDrag(beforeElement: Self?,
                                   afterElement: Self?) -> Range<Int> {
        guard let beforeElement = beforeElement else {
            return 0..<1
        }
        
        let beforeGroupIndex = beforeElement.sidebarIndex.groupIndex
        guard let afterElement = afterElement else {
            // Allow any nesting at end of list
            return 0..<beforeGroupIndex + (beforeElement.isGroup ? 2 : 1)
        }
        
        let afterGroupIndex = afterElement.sidebarIndex.groupIndex
        
        // If before element is a parent, restrict results from:
        // * min group: the after element group index
        // * max group: a child of this group
        if beforeElement.isGroup {
            let result = afterGroupIndex..<beforeGroupIndex + 2
            return result
        }
        
        // Default cases must remain in existing group unless last element in group
        let min = min(beforeGroupIndex, afterGroupIndex)
        let max = max(beforeGroupIndex, afterGroupIndex)
        let result = min..<max + 1
        return result
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
        self.dragPosition != nil
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
        // 15 pixels is enough to prevent a slight stutter that can exist
        let itemDrag = DragGesture(minimumDistance: 15)
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
//                print("SidebarItemGestureViewModel: longPressDragGesture: itemDrag onChanged")
                self.onItemDragChanged(value.translation)
            }.onEnded { _ in
//                print("SidebarItemGestureViewModel: longPressDragGesture: itemDrag onEnded")
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

#if targetEnvironment(macCatalyst)
        return
#endif
            
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

#if targetEnvironment(macCatalyst)
            return
#endif
            
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
    
    /// Helper that recursively travels nested data structure.
    func recursiveForEach(_ callback: @escaping (Element) -> ()) {
        self.forEach { item in
            callback(item)
            
            item.children?.recursiveForEach(callback)
        }
    }
    
    /// Helper that recursively travels nested data structure in DFS traversal (aka children first).
    func recursiveCompactMap(_ callback: @escaping (Element) -> Element?) -> [Element] {
        self.compactMap { item in
            item.children = item.children?.recursiveCompactMap(callback)
            
            return callback(item)
        }
    }
    
    /// Filters out collapsed groups.
    /// List mut be flattened for drag gestures.
    func getVisualFlattenedList() -> [Element] {
        self.flatMap { item in
            if let children = item.children,
               item.isExpandedInSidebar ?? false {
                return [item] + children.getVisualFlattenedList()
            }
            
            return [item]
        }
    }
    
//    /// Helper that recursively travels nested data structure.
//    func recursiveMap<T>(_ callback: @escaping (Element) -> T) -> [T] {
//        self.map { item in
//            let newItem = callback(item)
//            item.children = item.children?.map(callback)
//            return newItem
//        }
//    }
    
    @MainActor
    mutating private func insertDraggedElements(_ elements: [Element],
                                                at index: Int,
                                                shouldPlaceAfter: Bool = true) {
        let insertOffset = shouldPlaceAfter ? 1 : 0
        
        // Logic we want is to insert after the desired element, hence + 1
        self.insert(contentsOf: elements, at: index + insertOffset)
    }
    
    /// Recursive function that traverses nested array until index == 0.
    @MainActor
    func movedDraggedItems(_ draggedItems: [Element],
                           at dragResult: SidebarDragDestination<Element>,
                           dragPositionIndex: SidebarIndex) -> [Element] {
        guard let element = dragResult.element else {
            var newList = self
            newList.insertDraggedElements(draggedItems,
                                          at: 0,
                                          shouldPlaceAfter: false)
            return newList
        }
        
        guard let indexAtHierarchy = self.firstIndex(where: { $0.id == element.id }) else {
            // Recurse children until element found
            return self.map { item in
                item.children = item.children?.movedDraggedItems(draggedItems,
                                                                 at: dragResult,
                                                                 dragPositionIndex: dragPositionIndex)
                return item
            }
        }
        
        var newList = self
        
        switch dragResult {
        case .afterElement:
            newList.insertDraggedElements(draggedItems,
                                          at: indexAtHierarchy,
                                          shouldPlaceAfter: true)
            return newList
        
        case .topOfGroup:
            assertInDebug(element.isGroup)
            guard var children = element.children else {
                fatalErrorIfDebug()
                return self
            }
            
            children.insertDraggedElements(draggedItems,
                                           at: 0,
                                           shouldPlaceAfter: false)
            element.children = children
            newList[indexAtHierarchy] = element
            
            return newList
        }
    }
    
    /// Given some made-up location, finds the closest element in a nested sidebar list. Used for item dragging.
    /// Rules:
    ///     * Must match the group index
    ///     * Must ponit to group layer if otherwise top of list
    ///     * Recommended element cannot reside "below" the requested row index.
    /// Note: the enum result type determines if an element is placed either after some other element or into the list of a group.
    /// The enum is needed because there's no way to insert the element at the top of a list when the default rule is placing an element after.
    @MainActor
    func findClosestElement(draggedElement: Element,
                            to indexOfDraggedLocation: SidebarIndex) -> SidebarDragDestination<Element> {
        let beforeElement = self[safe: indexOfDraggedLocation.rowIndex - 1]
        let afterElement = self[safe: indexOfDraggedLocation.rowIndex]
        
        let supportedGroupRanges = draggedElement
            .supportedGroupRangeOnDrag(beforeElement: beforeElement,
                                       afterElement: afterElement)
        
        // Filters for:
        // 1. Row indices smaller than index--we want all because we could append after a group which is higher up the stack.
        // 2. Rows with allowed groups--which are constrained by the index's above and below element.
        let flattenedItems = self[0..<Swift.max(0, Swift.min(indexOfDraggedLocation.rowIndex, self.count))]
            .filter {
                let thisGroupIndex = $0.sidebarIndex.groupIndex
                return supportedGroupRanges.contains(thisGroupIndex)
            }
        
        // Prioritize correct group hierarchy--if equal use closest row index
        let rankedItems = flattenedItems.sorted { lhs, rhs in
            let lhsGroupIndexDiff = abs(indexOfDraggedLocation.groupIndex - lhs.sidebarIndex.groupIndex)
            let lhsRowIndexDiff = abs(indexOfDraggedLocation.rowIndex - lhs.sidebarIndex.rowIndex)
            
            let rhsGroupIndexDiff = abs(indexOfDraggedLocation.groupIndex - rhs.sidebarIndex.groupIndex)
            let rhsRowIndexDiff = abs(indexOfDraggedLocation.rowIndex - rhs.sidebarIndex.rowIndex)
            
            // Equal groups
            if lhsGroupIndexDiff == rhsGroupIndexDiff {
                return lhsRowIndexDiff < rhsRowIndexDiff
            }

            return lhsGroupIndexDiff < rhsGroupIndexDiff
        }
        
#if DEV_DEBUG
//        log("before: \(beforeElement?.id.debugFriendlyId ?? "none")\tafter: \(afterElement?.id.debugFriendlyId ?? "none")")
//        log("supported group ranges: \(supportedGroupRanges)")
//        log("recommendation test for \(indexOfDraggedLocation):")
//        rankedItems.forEach { print("\($0.id.debugFriendlyId), \($0.sidebarIndex), diff: \(abs(indexOfDraggedLocation.rowIndex - $0.sidebarIndex.rowIndex))") }
#endif
        
        // Covers top of list and many top of group scenarios
        guard let recommendedItem = rankedItems.first else {
            return .topOfGroup(beforeElement)
        }
        
        // Check if element is dragged more right-ward for placement into group
        if let beforeElement = beforeElement {
            // Horizontal drag is east of parent group
            let isDraggedIntoChildHierarchy = indexOfDraggedLocation.groupIndex > recommendedItem.sidebarIndex.groupIndex
            
            // Horizontal drag permits west-ward movement to move to parent context
            let allowsDraggingToParentHierarchy = supportedGroupRanges.contains(beforeElement.sidebarIndex.groupIndex)
            
            // User dragged into child list and that was allowed given below items
            let wasValidDragIntoChildren = isDraggedIntoChildHierarchy || !allowsDraggingToParentHierarchy
            
            let didMoveToTopOfGroup = beforeElement.isGroup && wasValidDragIntoChildren
            if didMoveToTopOfGroup {
                return .topOfGroup(beforeElement)
            }
        }
        
        // Default scenarios result in placing after some other element
        return .afterElement(recommendedItem)
    }
}
