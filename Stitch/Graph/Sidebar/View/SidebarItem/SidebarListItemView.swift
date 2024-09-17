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
    
    // white when layer is non-edit-mode selected; else determined by primary vs secondary selection status
    let color: Color
    
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
                color: color,
                selection: selection,
                isHidden: isHidden,
                isBeingEdited: isBeingEdited,
                isGroup: item.isGroup,
                isClosed: isClosed)
            
//            .padding(.leading)
            
                .offset(x: -swipeOffset)
            Spacer()

        }
        .contentShape(Rectangle()) // for hit area

        //        .background(Color.white.opacity(0.001)) // for hit area
//        .background(.ultraThinMaterial.opacity(isBeingDragged ? 1 : 0))
//        .background(.thinMaterial.opacity(isNonEditModeSelected ? 1 : 0))
                
        .frame(height: SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT)
        .background {
            if isNonEditModeSelected || isBeingDragged {
                theme.fontColor
            }
        }
        
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
                .stroke(isProposedGroup ? theme.fontColor : Color.clear,
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
