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
    
    @Environment(\.appTheme) var theme
    
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
    let isHovered: Bool
    
    // The actual rendered distance for the swipe distance
    @State var swipeX: CGFloat = 0
    @ObservedObject var gestureViewModel: SidebarItemGestureViewModel
    
    var showMainItem: Bool { swipeX < DEFAULT_ACTION_THRESHOLD }
    
    var itemIndent: CGFloat { item.location.x }
        
    @MainActor
    var isHidden: Bool {
        graph.getVisibilityStatus(for: item.id.asNodeId) != .visible
    }
    
    var fontColor: Color {
        
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
    
    var layerNodeId: LayerNodeId {
        item.id.asLayerNodeId
    }
    
    var isBeingDragged: Bool {
        current.map { $0.current == item.id } ?? false
    }
    
    var isNonEditModeFocused: Bool {
        graph.sidebarSelectionState.inspectorFocusedLayers.focused.contains(layerNodeId)
    }
    
    var isNonEditModeActivelySelected: Bool {
        graph.sidebarSelectionState.inspectorFocusedLayers.activelySelected.contains(layerNodeId)
    }
    
    var isNonEditModeSelected: Bool {
        isNonEditModeFocused || isNonEditModeActivelySelected
    }
    
    var isImplicitlyDragged: Bool {
        graph.sidebarSelectionState.implicitlyDragged.contains(item.id)
    }
    
    var useHalfOpacityBackground: Bool {
        isImplicitlyDragged || (isNonEditModeFocused && !isNonEditModeActivelySelected)
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
    
    var body: some View {
        HStack(spacing: .zero) {
            
            // Main row hides if swipe menu exceeds threshold
            if showMainItem {
                SidebarListItemView(graph: graph,
                                    item: item,
                                    name: name,
                                    layer: layer,
                                    current: current,
                                    proposedGroup: proposedGroup,
                                    isClosed: isClosed,
                                    fontColor: fontColor,
                                    selection: selection,
                                    isBeingEdited: isBeingEdited,
                                    isHidden: isHidden,
                                    swipeOffset: swipeX)
                .padding(.leading, itemIndent + 5)
                .background {
                    theme.fontColor
                        .opacity(self.backgroundOpacity)
                }
                // right-side label overlay comes AFTER x-placement of item,
                // so as not to be affected by x-placement.
                .overlay(alignment: .trailing) {
                    
#if !targetEnvironment(macCatalyst)
                    SidebarListItemRightLabelView(
                        item: item,
                        isGroup: item.isGroup,
                        isClosed: isClosed,
                        fontColor: fontColor,
                        selection: selection,
                        isBeingEdited: isBeingEdited,
                        isHidden: isHidden)
                    .frame(height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
                    
#endif
                    
//                    // TODO: revisit this; currently still broken on Catalyst and the UIKitTappableWrapper becomes unresponsive as soon as we apply a SwiftUI .frame or .offset; `Spacer()`s also do not seem to work
//                    // Hovering can happen on either Catalyst or iPad
//                    if isHovered {
//                        HStack {
//                            Spacer()
//                            UIKitTappableWrapper {
//                                log("clicked hover icon for \(layerNodeId)")
//                                dispatch(SidebarItemHiddenStatusToggled(clickedId: layerNodeId))
//                            } view: {
//                                Spacer()
//                                Image(systemName: isHidden ? SIDEBAR_VISIBILITY_STATUS_HIDDEN_ICON : SIDEBAR_VISIBILITY_STATUS_VISIBLE_ICON)
//                                    .foregroundColor(fontColor)
//                            }
//                        } // HStack
//                    } // if isHovered
                    
                }
                .padding(.trailing, 2)
                
            }
            
#if !targetEnvironment(macCatalyst)
            SidebarListItemSwipeMenu(
                item: item,
                swipeOffset: swipeX,
                visStatusIconName: graph.getLayerNode(id: item.id.id)?.layerNode?.visibilityStatusIcon ?? SIDEBAR_VISIBILITY_STATUS_VISIBLE_ICON,
                gestureViewModel: self.gestureViewModel)
#endif
        }
        
        // Animates swipe distance if it gets pinned to its open or closed position.
        // Does NOT animate for normal swiping.
#if !targetEnvironment(macCatalyst)
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
#endif
        .animation(.stitchAnimation(duration: 0.25), value: showMainItem)
        .animation(.stitchAnimation(duration: 0.25), value: itemIndent)
    }
}
