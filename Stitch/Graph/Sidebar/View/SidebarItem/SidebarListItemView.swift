//
//  _SidebarListItemView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit

struct SidebarListItemView: View {

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
    let isHidden: Bool

    let swipeOffset: CGFloat

    var isBeingDragged: Bool {
        current.map { $0.current == item.id } ?? false
    }

    var isProposedGroup: Bool {
        proposedGroup?.parentId == item.id
    }

    var layerNodeId: LayerNodeId {
        item.id.asLayerNodeId
    }
    
    var isNonEditModeSelected: Bool {
        graph.sidebarSelectionState.inspectorFocusedLayers.contains(layerNodeId)
    }
        
    var body: some View {

        HStack(spacing: 0) {
            SidebarListItemLeftLabelView(
                graph: graph,
                name: name,
                layer: layer,
                nodeId: layerNodeId,
                selection: selection,
                isHidden: isHidden,
                isBeingEdited: isBeingEdited,
                isGroup: item.isGroup,
                isClosed: isClosed)
            
//            .padding(.leading)
            
                .offset(x: -swipeOffset)
            Spacer()

        }
//        .frame(maxWidth: .infinity, 
////               maxHeight: .infinity)
//               maxHeight: SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT)
        
        .border(.black)
        
//        .frame(height: SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT)
        
        .background(Color.white.opacity(0.001)) // for hit area
//        .background(.ultraThinMaterial.opacity(isBeingDragged ? 1 : 0))
//        .background(.thinMaterial.opacity(isNonEditModeSelected ? 1 : 0))
        
//        .background(.ultraThinMaterial.opacity(isBeingDragged ? 1 : 0))
        
        .frame(height: SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT)
        .background {
            if isNonEditModeSelected || isBeingDragged {
                ZStack {
                    VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
                    theme.fontColor.opacity(0.7)
                }
            }
        }
        
        
        
        //        #if DEV_DEBUG
        //        .background(.blue.opacity(0.5)) // DEBUG
        //        #endif
        .cornerRadius(SWIPE_FULL_CORNER_RADIUS)
        
        // Note: given that we apparently must use the UIKitTappableWrapper on the swipe menu buttons,
        // we need to place the SwiftUI TapGesture below the swipe menu.
        .gesture(TapGesture().onEnded({ _ in
            if !isBeingEdited {
                dispatch(SidebarItemTapped(id: layerNodeId))
            }
        }))
        
        .overlay {
            RoundedRectangle(cornerRadius: SWIPE_FULL_CORNER_RADIUS)
                .stroke(isProposedGroup ? STITCH_TITLE_FONT_COLOR : Color.clear,
                        lineWidth: isProposedGroup ? 1 : 0)
        }
        .animation(.default, value: isProposedGroup)
        .animation(.default, value: isBeingDragged)
    }
}

// struct CustomListItemView_Previews: PreviewProvider {
//    static var previews: some View {
//        //        CustomListItemView()
//        TEST_CustomListItemBaseView()
//    }
// }
