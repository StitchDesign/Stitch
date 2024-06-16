//
//  SidebarListActiveGesture.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI

let SIDEBAR_ACTIVE_GESTURE_SCROLL_THRESHOLD: CGFloat = 20
let SIDEBAR_ACTIVE_GESTURE_SWIPE_THRESHOLD: CGFloat = SIDEBAR_ACTIVE_GESTURE_SCROLL_THRESHOLD

typealias LongPressAndDragGestureType = SequenceGesture<_EndedGesture<LongPressGesture>, DragGestureType>

typealias DragGestureType = _EndedGesture<_ChangedGesture<DragGesture>>

enum SidebarListActiveGesture: Equatable {
    case scrolling, // scrolling the entire list
         dragging(SidebarListItemId), // drag or (long press + drag); on a single item
         swiping, // swiping single item
         none

    var isScroll: Bool {
        switch self {
        case .scrolling:
            return true
        default:
            return false
        }
    }

    var isDrag: Bool {
        switch self {
        case .dragging:
            return true
        default:
            return false
        }
    }

    var dragId: SidebarListItemId? {
        switch self {
        case .dragging(let x):
            return x
        default:
            return nil
        }
    }

    var isSwipe: Bool {
        switch self {
        case .swiping:
            return true
        default:
            return false
        }
    }

    var isNone: Bool {
        switch self {
        case .none:
            return true
        default:
            return false
        }
    }
}
