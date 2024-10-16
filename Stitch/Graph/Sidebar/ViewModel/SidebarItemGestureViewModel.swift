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

final class SidebarItemGestureViewModel: ObservableObject {
    let item: SidebarListItem

    // published property to be read in view
    @Published var swipeSetting: SidebarSwipeSetting = .closed

    private var previousSwipeX: CGFloat = 0
    @Binding var activeGesture: SidebarListActiveGesture {
        didSet {
            switch activeGesture {
            // scrolling or dragging resets swipe-menu
            case .scrolling, .dragging:
                resetSwipePosition()
            default:
                return
            }
        }
    }

    // Tracks if the edit menu is open
    var editOn: Bool = false
    @Binding var activeSwipeId: SidebarListItemId?

    init(item: SidebarListItem,
         activeGesture: Binding<SidebarListActiveGesture>,
         activeSwipeId: Binding<SidebarListItemId?>) {
        self.item = item
        self._activeGesture = activeGesture
        self._activeSwipeId = activeSwipeId
    }

    // MARK: GESTURE HANDLERS

    @MainActor
    var onItemDragChanged: OnItemDragChangedHandler {
        return { (translation: CGSize) in
            // print("SidebarItemGestureViewModel: itemDragChangedGesture called")
            self.activeGesture = .dragging(self.item.id)
            dispatch(SidebarListItemDragged(
                        itemId: self.item.id,
                        translation: translation))
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
                dispatch(SidebarListItemDragEnded(itemId: self.item.id))
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
            dispatch(SidebarListItemLongPressed(id: self.item.id))
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
            
#if targetEnvironment(macCatalyst)
        return
#endif
            
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
            
#if targetEnvironment(macCatalyst)
        return
#endif

            // if we had been swiping, then we reset activeGesture
            if self.activeGesture.isSwipe {
                //                print("SidebarItemGestureViewModel: itemSwipeEndedGesture onEnded: resetting swipe")
                self.activeGesture = .none
                if self.atDefaultActionThreshold {
                    // Don't need to change x position here,
                    // since redOption's offset handles that.
                    dispatch(SidebarItemDeleted(itemId: self.item.id))
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
