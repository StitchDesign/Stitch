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
    
    // white when layer is non-edit-mode selected; else determined by primary vs secondary selection status
    let color: Color
    
    let selection: SidebarListItemSelectionStatus
    let isHidden: Bool
    let isBeingEdited: Bool
    let isGroup: Bool
    let isClosed: Bool
   
    @State private var isBeingEditedAnimated = false
        
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
            .layerNode?.masksPort.allLoopedValues
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
    
    var body: some View {
        HStack(spacing: 4) {
//        HStack(spacing: 0) {
            
            if masks {
                Image(systemName: MASKS_LAYER_ABOVE_ICON_NAME)
//                    .scaleEffect(1.2) // previously: 1.0 or 1.4
                    .resizable()
                    .scaledToFit()
                #if targetEnvironment(macCatalyst)
                    .padding(2)
                #else
                    .padding(4)
                #endif
                    .frame(width: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT,
                           height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
                    .foregroundColor(color)
                    .opacity(masks ? 1 : 0)
                    .animation(.linear, value: masks)
                    // .border(.red)
            }
            
//            if isGroup {
                SidebarListItemChevronView(isClosed: isClosed,
                                           parentId: nodeId,
                                           color: color,
                                           isHidden: isHidden)
                .opacity(isGroup ? 1 : 0)
                // .border(.green)
//            }
  
            Image(systemName: layer.sidebarLeftSideIcon)
                .resizable()
                .scaledToFit()
                .padding(2)
                .frame(width: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT,
                       height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
                .foregroundColor(color)
                // .border(.yellow)
            
            label
                .foregroundColor(color)
        }
        .padding(.leading, 4)
//        .padding(.leading, isGroup ? 4 : 0)
        .frame(height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
    }
    
    var label: some View {
        Group {
            if isBeingEdited {
                StitchTextView(string: _name,
                               font: SIDEBAR_LIST_ITEM_FONT,
                               fontColor: color)
                .truncationMode(.tail)
#if targetEnvironment(macCatalyst)
                .padding(.trailing, 44)
#else
                .padding(.trailing, 60)
#endif
            } else {
                StitchTextView(string: _name,
                               font: SIDEBAR_LIST_ITEM_FONT,
                               fontColor: color)
            }
        }
        .lineLimit(1)
    }
}

struct SidebarListItemRightLabelView: View {

    let item: SidebarListItem
    let isGroup: Bool
    let isClosed: Bool
    
    // white when layer is non-edit-mode selected; else determined by primary vs secondary selection status
    let color: Color
    
    let selection: SidebarListItemSelectionStatus
    let isBeingEdited: Bool // is sidebar being edited?
    let isHidden: Bool

    @State private var isBeingEditedAnimated = false
    
    var body: some View {

        let id = item.id.asLayerNodeId

        HStack(spacing: .zero) {
            
            if isBeingEditedAnimated {
                HStack(spacing: .zero) {
                    SidebarListItemSelectionCircleView(id: id,
                                                       color: color,
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
        .frame(height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
    }
}

let EDIT_MODE_HAMBURGER_DRAG_ICON = "line.3.horizontal"
let EDIT_MODE_HAMBURGER_DRAG_ICON_COLOR: Color = .gray // Always gray, whether light or dark mode

// TODO: on iPad, dragging the hamburger icon should immediately drag the sidebar-item without need for long press first
struct SidebarListDragIconView: View {

    let item: SidebarListItem

    var body: some View {
        Image(systemName: EDIT_MODE_HAMBURGER_DRAG_ICON)
        // TODO: Should use white if this sidebar layer is selected?
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
