//
//  _SidebarListItemView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit
import GameController

struct SidebarListItemView: View {

    @Environment(\.appTheme) var theme
    
    @Bindable var graph: GraphState
    
    @EnvironmentObject var keyboardObserver: KeyboardObserver
    
    var item: SidebarListItem
    let name: String
    let layer: Layer
    var current: SidebarDraggedItem?
    var proposedGroup: ProposedGroup?
    var isClosed: Bool
    
    // white when layer is non-edit-mode selected; else determined by primary vs secondary selection status
    let fontColor: Color
    
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
    
    var isNonEditModeFocused: Bool {
        graph.sidebarSelectionState.inspectorFocusedLayers.focused.contains(layerNodeId)
    }
    
    var isNonEditModeActivelySelected: Bool {
        graph.sidebarSelectionState.inspectorFocusedLayers.activelySelected.contains(layerNodeId)
    }
    
    var isNonEditModeSelected: Bool {
        isNonEditModeFocused || isNonEditModeActivelySelected
    }
        
    var body: some View {

        HStack(spacing: 0) {
            SidebarListItemLeftLabelView(
                graph: graph,
                name: name,
                layer: layer,
                nodeId: layerNodeId,
                fontColor: fontColor,
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

        //        .background(.ultraThinMaterial.opacity(isBeingDragged ? 1 : 0))
        //        .background(.thinMaterial.opacity(isNonEditModeSelected ? 1 : 0))
                
        .frame(height: SIDEBAR_LIST_ITEM_ROW_COLORED_AREA_HEIGHT)
        
        // Note: to have color limited by indentation level etc.:
        
//        .background {
//            if isNonEditModeSelected || isBeingDragged {
//                theme.fontColor
//                    .opacity((isNonEditModeFocused && !isNonEditModeActivelySelected) ? 0.5 : 1)
////                    .frame(maxWidth: .infinity)
////                    .border(.green, width: 4)
//            }
//        }
        
//        .cornerRadius(SWIPE_FULL_CORNER_RADIUS)
        
        .onTapGesture {
            if !isBeingEdited {
                // Note: seems better to query the keyboard observer in the actual on-tap-gesture ?
                let isShiftDown = keyboardObserver.keyboard?.keyboardInput?.isShiftPressed ?? false
                dispatch(SidebarItemTapped(id: layerNodeId,
                                           shiftHeld: isShiftDown))
            }
        }
    
        .overlay {
            RoundedRectangle(cornerRadius: SWIPE_FULL_CORNER_RADIUS)
                .stroke(isProposedGroup ? theme.fontColor : Color.clear,
                        lineWidth: isProposedGroup ? 1 : 0)
            // Preferably animate the smallest view possible; when this .animation was applied outside the .overlay, we undesiredly animated text color changes
                .animation(.default, value: isProposedGroup)
        }
        .animation(.default, value: isBeingDragged)
    }
}

extension GCKeyboardInput {
    var isShiftPressed: Bool {
        let leftShiftPressed = self.button(forKeyCode: .leftShift)?.isPressed ?? false
        let rightShiftPressed = self.button(forKeyCode: .rightShift)?.isPressed ?? false
        return leftShiftPressed || rightShiftPressed
    }
}
