//
//  SidebarListItemSwipeInnerView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeInnerView<SidebarItemViewModel>: View where SidebarItemViewModel: SidebarItemSwipable {
    // The actual rendered distance for the swipe distance
    @State private var swipeX: CGFloat = 0
    @Environment(\.appTheme) private var theme
    
    @Bindable var graph: GraphState
    @Bindable var sidebarViewModel: SidebarItemViewModel.SidebarViewModel
    @Bindable var itemViewModel: SidebarItemViewModel.ItemViewModel
    
    let name: String
//    let layer: Layer
    var isClosed: Bool
    let selection: SidebarListItemSelectionStatus
    let swipeSetting: SidebarSwipeSetting
    let sidebarWidth: CGFloat

    var isBeingEdited: Bool { self.sidebarViewModel.isEditing }
    
    var showMainItem: Bool { swipeX < DEFAULT_ACTION_THRESHOLD }
    
    var itemIndent: CGFloat { itemViewModel.location.x }
    
    var fontColor: Color {
        self.itemViewModel.fontColor
    }
    
//    var layerNodeId: LayerNodeId {
//        item.id.asLayerNodeId
//    }
    
    var body: some View {
        HStack(spacing: .zero) {
            
            // Main row hides if swipe menu exceeds threshold
            if showMainItem {
                SidebarListItemView(graph: graph,
                                    sidebarViewModel: sidebarViewModel,
                                    itemViewModel: itemViewModel,
                                    name: name,
//                                    layer: layer,
                                    isClosed: isClosed,
                                    fontColor: fontColor,
                                    selection: selection,
//                                    isHidden: isHidden,
                                    swipeOffset: swipeX)
                .padding(.leading, itemIndent + 5)
                .background {
                    theme.fontColor
                        .opacity(itemViewModel.backgroundOpacity)
                }
                // right-side label overlay comes AFTER x-placement of item,
                // so as not to be affected by x-placement.
                .overlay(alignment: .trailing) {
                    SidebarListItemRightLabelView(
                        item: itemViewModel,
                        isGroup: itemViewModel.isGroup,
                        isClosed: isClosed,
                        fontColor: fontColor,
                        selection: selection,
                        isBeingEdited: isBeingEdited)
                    .frame(height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
                }
                .padding(.trailing, 2)
                
            }
            
            SidebarListItemSwipeMenu(
                gestureViewModel: itemViewModel,
                swipeOffset: swipeX,
                visStatusIconName: graph.getLayerNode(id: itemViewModel.id)?.layerNode?.visibilityStatusIcon ?? SIDEBAR_VISIBILITY_STATUS_VISIBLE_ICON)
        }
        
        // Animates swipe distance if it gets pinned to its open or closed position.
        // Does NOT animate for normal swiping.
        .onChange(of: swipeSetting) { newSwipeSetting in
            switch newSwipeSetting {
            case .closed, .open:
                                
//                withAnimation { // has weird behavior at end of closing animation
                
//                withAnimation(.linear(duration: 0.1)) {
//                withAnimation(.easeInOut(duration: 0.2)) {
//                withAnimation(.easeInOut(duration: 0.3)) {
                
                // Feels just right?
                withAnimation(.easeInOut(duration: 0.25)) {
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
