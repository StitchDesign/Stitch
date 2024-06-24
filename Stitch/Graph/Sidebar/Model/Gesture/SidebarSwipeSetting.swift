//
//  SidebarSwipeSetting.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation

/// Represents each mode of a swipe gesture on a sidebar item. Open and closed positions are fixed.
enum SidebarSwipeSetting: Equatable {
    case closed
    case swiping(CGFloat)
    case open

    var distance: CGFloat {
        switch self {
        case .closed:
            return 0
        case .swiping(let distance):
            return distance
        case .open:
            return RESTING_THRESHOLD_POSITION
        }
    }
}
