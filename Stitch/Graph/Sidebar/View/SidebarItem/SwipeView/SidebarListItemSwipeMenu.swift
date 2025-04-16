//
//  SidebarListItemSwipeMenu.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeMenu<Item>: View where Item: SidebarItemSwipable {
    @Bindable var gestureViewModel: Item
    @Bindable var graph: GraphState
    let swipeOffset: CGFloat
    
    var showNonDefaultOptions: Bool { swipeOffset < DEFAULT_ACTION_THRESHOLD }

    @MainActor
    var visStatusIconName: String {
        gestureViewModel.isVisible(graph: graph) ? SIDEBAR_VISIBILITY_STATUS_VISIBLE_ICON : SIDEBAR_VISIBILITY_STATUS_HIDDEN_ICON
    }
    
    var body: some View {
        HStack(spacing: 2) {
            // Hide other options after sufficient swipe
            if showNonDefaultOptions {
                SidebarListItemSwipeButton(sfImageName: "ellipsis.circle",
                                           backgroundColor: GREY_SWIPE_MENU_OPTION_COLOR,
                                           gestureViewModel: gestureViewModel) { }
                
                SidebarListItemSwipeButton(sfImageName: visStatusIconName,
                                           backgroundColor: STITCH_PURPLE,
                                           gestureViewModel: gestureViewModel) {
                    gestureViewModel.didToggleVisibility()
                }
            }
            
            SidebarListItemSwipeButton(sfImageName: "trash",
                                       backgroundColor: Color(.stitchRed),
                                       willLeftAlign: !showNonDefaultOptions,
                                       gestureViewModel: gestureViewModel) {
                gestureViewModel.didDeleteItem()
            }
        }
        .animation(.stitchAnimation(duration: 0.25), value: showNonDefaultOptions)
        .disabled(swipeOffset == 0)
        .width(showNonDefaultOptions ? swipeOffset : .infinity)
        .frame(height: SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT)
        .cornerRadius(SWIPE_FULL_CORNER_RADIUS)
    }
}
