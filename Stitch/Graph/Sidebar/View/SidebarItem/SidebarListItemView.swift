//
//  _SidebarListItemView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit
import GameController

struct SidebarListItemView<SidebarViewModel>: View where SidebarViewModel: ProjectSidebarObservable {
    typealias ItemID = SidebarViewModel.ItemID

    @Environment(\.appTheme) private var theme
    @EnvironmentObject private var keyboardObserver: KeyboardObserver
    
    @Bindable var graph: GraphState
    @Bindable var sidebarViewModel: SidebarViewModel
    
    var item: SidebarViewModel.ItemViewModel
    let name: String
//    let layer: Layer

    var isClosed: Bool
    
    // white when layer is non-edit-mode selected; else determined by primary vs secondary selection status
    let fontColor: Color
    
    let selection: SidebarListItemSelectionStatus

//    let isHidden: Bool

    let swipeOffset: CGFloat

    var isBeingEdited: Bool {
        self.sidebarViewModel.isEditing
    }
    
    var current: SidebarDraggedItem<ItemID>? {
        self.sidebarViewModel.currentItemDragged
    }
    
    var proposedGroup: ProposedGroup<SidebarViewModel.ID>? {
        self.sidebarViewModel.proposedGroup
    }

    // TODO: should be for *all* selected-layers during a drag
    var isBeingDragged: Bool {
        current.map { $0.current == item.id } ?? false
    }

    var isProposedGroup: Bool {
        proposedGroup?.parentId == item.id
    }
    
    var isNonEditModeFocused: Bool {
        sidebarViewModel.inspectorFocusedLayers.focused.contains(item.id)
    }
    
    var isNonEditModeActivelySelected: Bool {
        sidebarViewModel.inspectorFocusedLayers.activelySelected.contains(item.id)
    }
    
    var isNonEditModeSelected: Bool {
        isNonEditModeFocused || isNonEditModeActivelySelected
    }
  
    var body: some View {

        HStack(spacing: 0) {
            SidebarListItemLeftLabelView(
                graph: graph,
                sidebarViewModel: sidebarViewModel,
                name: name,
//                layer: layer,
                fontColor: fontColor,
                selection: selection,
//                isHidden: isHidden,
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
        
//        .onTapGesture {
//            if !isBeingEdited {
//                // Note: seems better to query the keyboard observer in the actual on-tap-gesture ?
//                let isShiftDown = keyboardObserver.keyboard?.keyboardInput?.isShiftPressed ?? false
//                dispatch(SidebarItemTapped(id: layerNodeId,
//                                           shiftHeld: isShiftDown))
//            }
//        }
    
        .overlay {
            RoundedRectangle(cornerRadius: SWIPE_FULL_CORNER_RADIUS)
                .stroke(isProposedGroup ? theme.fontColor : Color.clear,
                        lineWidth: isProposedGroup ? 1 : 0)
            // Preferably animate the smallest view possible; when this .animation was applied outside the .overlay, we undesiredly animated text color changes
                .animation(.default, value: isProposedGroup)
        }

        // TODO: needs to be for all actively-dragged selected layers
//        .animation(.default, value: isBeingDragged)
    }
}

extension GCKeyboardInput {
    var isShiftPressed: Bool {
        let leftShiftPressed = self.button(forKeyCode: .leftShift)?.isPressed ?? false
        let rightShiftPressed = self.button(forKeyCode: .rightShift)?.isPressed ?? false
        return leftShiftPressed || rightShiftPressed
    }
}
