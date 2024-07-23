//
//  _SidebarListLabelViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit

struct SidebarListItemLeftLabelView: View {

    @Bindable var graph: GraphState
    
    let name: String
    let layer: Layer
    let nodeId: LayerNodeId // debug
    let selection: SidebarListItemSelectionStatus
    let isHidden: Bool
    let isBeingEdited: Bool
   
    var color: Color {
        selection.color(isHidden)
    }
    
    // TODO: perf: will this GraphState-reading computed variable cause SidebarListItemLeftLabelView to render too often?
    
    // TODO: should we only show the arrow icon when we have a sidebar layer immediately above?
    @MainActor
    var masks: Bool {
        
        // TODO: why is this not animated? and why does it jitter?
//        // index of this layer
//        guard let index = graph.sidebarListState.masterList.items
//            .firstIndex(where: { $0.id.asLayerNodeId == nodeId }) else {
//            return withAnimation { false }
//        }
//        
//        // hasSidebarLayerImmediatelyAbove
//        guard graph.sidebarListState.masterList.items[safe: index - 1].isDefined else {
//            return withAnimation { false }
//        }
//        
        let atleastOneIndexMasks = graph
            .getLayerNode(id: nodeId.id)?
            .layerNode?
            .masksPort
            .allLoopedValues
            .contains(where: { $0.getBool ?? false })
        ?? false
        
        return withAnimation {
            atleastOneIndexMasks
        }
    }
    
    
    var _name: String {
        return name
        
//#if DEV_DEBUG
//        name + " \(nodeId.id.debugFriendlyId)"
//#else
//        name
//#endif
    }
    
    var label: some View {
            Group {
                if isBeingEdited {
                    Text(_name)
                        .truncationMode(.tail)
                        #if targetEnvironment(macCatalyst)
                        .padding(.trailing, 44)
                        #else
                        .padding(.trailing, 60)
                        #endif
                } else {
                    Text(_name)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
            }
            .lineLimit(1)
    }

    var body: some View {
      
        if isBeingEdited {
            labelHStack
            // Note: color animation when resetting swipe causes the text-label to lag behind; most important color-animation case is for selecting layer-groups in sidebar, so we just limit color animation to edit-mode.
            // TODO: how to animate color when user hides layer node via graph?
                .animation(.linear, value: color)
        } else {
            labelHStack
        }
        
    }
    
    @MainActor
    var labelHStack: some View {
        HStack {
            if masks {
                Image(systemName: MASKS_LAYER_ABOVE_ICON_NAME)
                    .scaleEffect(1.2) // previously: 1.0 or 1.4
                    .foregroundColor(color)
                    .opacity(masks ? 1 : 0)
                    .animation(.linear, value: masks)
            }
  
            Image(systemName: layer.sidebarLeftSideIcon)
                .scaleEffect(1.2) // previously: 1.0 or 1.4
                .foregroundColor(color)
            
            label
                .font(SwiftUI.Font.system(size: 18))
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

struct SidebarListItemRightLabelView: View {

    let item: SidebarListItem
    let isGroup: Bool
    let isClosed: Bool
    let selection: SidebarListItemSelectionStatus
    let isBeingEdited: Bool // is sidebar being edited?
    let isHidden: Bool

    @State private var isBeingEditedAnimated = false

    var body: some View {

        let id = item.id.asLayerNodeId

        HStack(spacing: .zero) {
            if isGroup {
                SidebarListItemChevronView(isClosed: isClosed,
                                           parentId: id,
                                           selection: selection,
                                           isHidden: isHidden)
                    .padding(.trailing, isBeingEditedAnimated ? 0 : 4)
            }

            if isBeingEditedAnimated {
                HStack(spacing: .zero) {
                    SidebarListItemSelectionCircleView(id: id,
                                                       selection: selection,
                                                       isHidden: isHidden,
                                                       isBeingEdited: isBeingEdited)
                        .padding(.trailing, 4)

                    SidebarListDragIconView(item: item)
                        .padding(.trailing, 4)
                }
                .transition(.slideInAndOut)
            }
        } // HStack
        // Animate padding so that icons and completely animate off screen
        .padding(.trailing, isBeingEditedAnimated ? 4 : 0)
        .stitchAnimated(willAnimateBinding: $isBeingEditedAnimated,
                        willAnimateState: isBeingEdited,
                        animation: .stitchAnimation(duration: 0.25))
    }
}

let EDIT_MODE_HAMBURGER_DRAG_ICON = "line.3.horizontal"
let EDIT_MODE_HAMBURGER_DRAG_ICON_COLOR: Color = .gray // Always gray, whether light or dark mode

// TODO: on iPad, dragging the hamburger icon should immediately drag the sidebar-item without need for long press first
struct SidebarListDragIconView: View {

    let item: SidebarListItem

    var body: some View {
        Image(systemName: EDIT_MODE_HAMBURGER_DRAG_ICON)
            .foregroundColor(EDIT_MODE_HAMBURGER_DRAG_ICON_COLOR)
            .scaleEffect(1.2)
            .frame(width: SIDEBAR_ITEM_ICON_LENGTH,
                   height: SIDEBAR_ITEM_ICON_LENGTH)
            .padding(4)
    }
}

#if targetEnvironment(macCatalyst)
let SIDEBAR_ITEM_ICON_LENGTH: CGFloat = 14
#else
let SIDEBAR_ITEM_ICON_LENGTH: CGFloat = 25
#endif
