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

protocol SidebarItemSwipable: AnyObject, Observable where Item.ID == SidebarViewModel.SidebarListItemId {
    associatedtype Item: Identifiable
    associatedtype SidebarViewModel: ProjectSidebarObservable
    typealias ActiveGesture = SidebarListActiveGesture<Item.ID>
    
    var item: Item { get }
    
    // published property to be read in view
    var swipeSetting: SidebarSwipeSetting { get set }

    var previousSwipeX: CGFloat { get set }
    
//    var activeGesture: ActiveGesture { get set }
    //    var activeSwipeId: Item.ID? { get set }
    
    var editOn: Bool { get set }
    
    var sidebarDelegate: SidebarViewModel? { get }
    
    var location: CGPoint { get }
    
    @MainActor
    func sidebarItemTapped(id: Item.ID,
                           shiftHeld: Bool,
                           commandHeld: Bool)
    
    @MainActor
    func sidebarListItemDragged(itemId: Item.ID,
                                translation: CGSize)
    
    @MainActor
    func sidebarListItemDragEnded(itemId: Item.ID)
    
    @MainActor
    func sidebarListItemLongPressed(id: Item.ID)
    
    @MainActor
    func sidebarItemDeleted(itemId: Item.ID)
    
    @MainActor
    func contextMenuInteraction(itemId: Item.ID,
                                graph: GraphState,
                                keyboardObserver: KeyboardObserver) -> UIContextMenuConfiguration?
    
    @MainActor
    func sidebarLayerHovered(itemId: Item.ID)
    
    @MainActor
    func sidebarLayerHoverEnded(itemId: Item.ID)
}

extension SidebarItemSwipable {
    var activeGesture: SidebarListActiveGesture<Self.Item.ID> {
        get {
            self.sidebarDelegate?.activeGesture ?? .none
        }
        set(newValue) {
            self.sidebarDelegate?.activeGesture = newValue
        }
    }
    
    var activeSwipeId: Self.Item.ID? {
        get {
            self.sidebarDelegate?.activeSwipeId ?? nil
        }
        set(newValue) {
            self.sidebarDelegate?.activeSwipeId = newValue
        }
    }
    
    // MARK: GESTURE HANDLERS

    @MainActor
    var onItemDragChanged: OnItemDragChangedHandler {
        return { (translation: CGSize) in
            // print("SidebarItemGestureViewModel: itemDragChangedGesture called")
            self.activeGesture = .dragging(self.item.id)
            self.sidebarListItemDragged(
                itemId: self.item.id,
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
                self.sidebarListItemDragEnded(itemId: self.item.id)
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
            self.activeGesture = .dragging(self.item.id)
            self.sidebarListItemLongPressed(id: self.item.id)
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
            if self.editOn {
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

                self.activeSwipeId = self.item.id
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

            if self.editOn {
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
                    self.sidebarItemDeleted(itemId: self.item.id)
                } else if self.hasCrossedRestingThreshold {
                    self.swipeSetting = .open
                }
                // we didn't pull it out far enough -- set x = 0
                else {
                    self.swipeSetting = .closed
                }
                self.previousSwipeX = self.swipeSetting.distance
                self.activeSwipeId = self.item.id
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
    let item: SidebarListItem
    
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
    var editOn: Bool = false
//    @Binding var activeSwipeId: SidebarListItemId?

    init(item: SidebarListItem,
         sidebarViewModel: LayersSidebarViewModel,
         graph: GraphState) {
        self.item = item
        self.sidebarDelegate = sidebarViewModel
        self.graphDelegate = graph
    }
}

extension SidebarItemGestureViewModel {
    var location: CGPoint {
        self.item.location
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
    
    @MainActor
    func sidebarListItemLongPressed(id: SidebarListItemId) {
        self.graphDelegate?.sidebarListItemLongPressed(id: id)
    }
    
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
