//
//  SidebarListItemSwipeMenu.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeMenu: View {
    let item: SidebarListItem
    let swipeOffset: CGFloat
    let visStatusIconName: String

    @ObservedObject var gestureViewModel: SidebarItemGestureViewModel
    
    var showNonDefaultOptions: Bool { swipeOffset < DEFAULT_ACTION_THRESHOLD }

    var body: some View {
        HStack(spacing: 2) {
            // Hide other options after sufficient swipe
            if showNonDefaultOptions {
                SidebarListItemSwipeButton(sfImageName: "ellipsis.circle",
                                           backgroundColor: GREY_SWIPE_MENU_OPTION_COLOR,
                                           gestureViewModel: gestureViewModel)
                
                SidebarListItemSwipeButton(action: SidebarItemHiddenStatusToggled(clickedId: item.id.asLayerNodeId),
                                           sfImageName: visStatusIconName,
                                           backgroundColor: STITCH_PURPLE,
                                           gestureViewModel: gestureViewModel)
            }
            
            SidebarListItemSwipeButton(action: SidebarItemDeleted(itemId: item.id),
                                       sfImageName: "trash",
                                       backgroundColor: Color(.stitchRed),
                                       willLeftAlign: !showNonDefaultOptions,
                                       gestureViewModel: gestureViewModel)
        }
        .animation(.stitchAnimation(duration: 0.25), value: showNonDefaultOptions)
        .disabled(swipeOffset == 0)
        .width(showNonDefaultOptions ? swipeOffset : .infinity)
        .frame(height: SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT)
        .cornerRadius(SWIPE_FULL_CORNER_RADIUS)
    }
}
