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
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var sidebarViewModel: SidebarViewModel
    @Bindable var item: SidebarViewModel.ItemViewModel
    let swipeOffset: CGFloat
    let fontColor: Color
    
    var isBeingEdited: Bool {
        self.sidebarViewModel.isEditing
    }

    var proposedGroup: SidebarViewModel.ItemViewModel? {
        self.sidebarViewModel.proposedGroup
    }

    var isProposedGroup: Bool {
        proposedGroup?.id == item.id
    }
    
    var isNonEditModeFocused: Bool {
        sidebarViewModel.selectionState.all.contains(item.id)
    }
    
    var isNonEditModeActivelySelected: Bool {
        sidebarViewModel.selectionState.primary.contains(item.id)
    }
    
    var isNonEditModeSelected: Bool {
        isNonEditModeFocused || isNonEditModeActivelySelected
    }
  
    var body: some View {

        HStack(spacing: 0) {
            SidebarListItemLeftLabelView(
                graph: graph,
                document: document,
                sidebarViewModel: sidebarViewModel,
                itemViewModel: item,
                fontColor: fontColor)
            
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
    }
}

extension GCKeyboardInput {
    var isShiftPressed: Bool {
        let leftShiftPressed = self.button(forKeyCode: .leftShift)?.isPressed ?? false
        let rightShiftPressed = self.button(forKeyCode: .rightShift)?.isPressed ?? false
        return leftShiftPressed || rightShiftPressed
    }
}
