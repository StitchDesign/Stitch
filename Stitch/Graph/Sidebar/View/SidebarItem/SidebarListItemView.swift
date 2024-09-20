//
//  _SidebarListItemView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit

struct SidebarListItemView: View {

    // Move this ... elsewhere? Globally?
    @State var keyboardObserver: KeyboardObserver = .init()
    
    @Environment(\.appTheme) var theme
    
    @Bindable var graph: GraphState
    
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
        
        // To have color limited by indentation level etc.:
        
//        .background {
//            if isNonEditModeSelected || isBeingDragged {
//                theme.fontColor
//                    .opacity((isNonEditModeFocused && !isNonEditModeActivelySelected) ? 0.5 : 1)
////                    .frame(maxWidth: .infinity)
////                    .border(.green, width: 4)
//            }
//        }
        
//        .cornerRadius(SWIPE_FULL_CORNER_RADIUS)
        
        // Note: given that we apparently must use the UIKitTappableWrapper on the swipe menu buttons,
        // we need to place the SwiftUI TapGesture below the swipe menu.
        .gesture(TapGesture().onEnded({ _ in
            if !isBeingEdited {
                
                let keyboardInput = keyboardObserver.keyboard?.keyboardInput
        
                let shiftIsPressed = keyboardInput?.button(
                    forKeyCode: .leftShift
                )?.isPressed ?? false || keyboardInput?.button(
                    forKeyCode: .rightShift
                )?.isPressed ?? false
                
                log("shiftIsPressed: \(shiftIsPressed)")
                
                dispatch(SidebarItemTapped(id: layerNodeId,
                                           shiftHeld: shiftIsPressed))
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

import GameController

class KeyboardObserver: ObservableObject {
    @Published var keyboard: GCKeyboard?
    
    var observer: Any? = nil
    
    init() {
        observer = NotificationCenter.default.addObserver(
            forName: .GCKeyboardDidConnect,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.keyboard = notification.object as? GCKeyboard
        }
    }
}
