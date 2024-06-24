//
//  SidebarListItemSwipeInnerView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeInnerView: View {
    
    @Bindable var graph: GraphState
    
    var item: SidebarListItem
    let name: String
    let layer: Layer
    var current: SidebarDraggedItem?
    var proposedGroup: ProposedGroup?
    var isClosed: Bool
    let selection: SidebarListItemSelectionStatus
    let isBeingEdited: Bool
    let swipeSetting: SidebarSwipeSetting
    let sidebarWidth: CGFloat

    // The actual rendered distance for the swipe distance
    @State var swipeX: CGFloat = 0
    @ObservedObject var gestureViewModel: SidebarItemGestureViewModel
    
    var showMainItem: Bool { swipeX < DEFAULT_ACTION_THRESHOLD }

    var itemIndent: CGFloat { item.location.x }

    var isHidden: Bool {
        graph.getVisibilityStatus(for: item.id.asNodeId) != .visible
    }

    var body: some View {
        HStack(spacing: .zero) {

            // Main row hides if swipe menu exceeds threshold
            if showMainItem {
                SidebarListItemView(
                    graph: graph,
                    item: item,
                    name: name,
                    layer: layer,
                    current: current,
                    proposedGroup: proposedGroup,
                    isClosed: isClosed,
                    selection: selection,
                    isBeingEdited: isBeingEdited,
                    isHidden: isHidden,
                    swipeOffset: swipeX)
                    .padding(.leading, itemIndent + 5)

                    // right-side label overlay comes AFTER x-placement of item,
                    // so as not to be affected by x-placement.
                    .overlay(alignment: .trailing) {
                        SidebarListItemRightLabelView(
                            item: item,
                            isGroup: item.isGroup,
                            isClosed: isClosed,
                            selection: selection,
                            isBeingEdited: isBeingEdited,
                            isHidden: isHidden)
                    }
            }

            if swipeX > 0 {
                SidebarListItemSwipeMenu(
                    item: item,
                    swipeOffset: swipeX,
                    visStatusIconName: graph.getLayerNode(id: item.id.id)?.layerNode?.visibilityStatusIcon ?? SIDEBAR_VISIBILITY_STATUS_VISIBLE_ICON,
                    gestureViewModel: self.gestureViewModel)
            }
        }

        // Animates swipe distance if it gets pinned to its open or closed position.
        // Does NOT animate for normal swiping.
        .onChange(of: swipeSetting) { newSwipeSetting in
            switch newSwipeSetting {
            case .closed, .open:
                withAnimation {
                    swipeX = newSwipeSetting.distance
                }
            case .swiping(let distance):
                swipeX = min(distance, sidebarWidth)
            }
        }
        .animation(.stitchAnimation(duration: 0.25), value: showMainItem)
        .animation(.stitchAnimation(duration: 0.25), value: itemIndent)
    }
}
