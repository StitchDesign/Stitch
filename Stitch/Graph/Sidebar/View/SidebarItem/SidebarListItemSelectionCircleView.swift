//
//  _SidebarListItemSelectionCircleView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit

struct SidebarListItemSelectionCircleView: View {
    
    static let SELECTION_CIRCLE_SELECTED = "circle.inset.filled"
    static let SELECTION_CIRCLE = "circle"

    let id: LayerNodeId
    
    // white when layer is non-edit-mode selected; else determined by primary vs secondary selection status
    let color: Color
    
    let selection: SidebarListItemSelectionStatus
    let isHidden: Bool
    let isBeingEdited: Bool
        
    var iconName: String {
        selection.isSelected
              ? Self.SELECTION_CIRCLE_SELECTED
              : Self.SELECTION_CIRCLE
    }
    
    var body: some View {
        // See `SidebarListItemLeftLabelView` for note about animations
        if isBeingEdited {
            selectionCircle
//                .animation(.linear, value: iconName)
        } else {
            selectionCircle
        }
    }
    
    @MainActor
    var selectionCircle: some View {
        Image(systemName: iconName)
            .foregroundColor(color)
            .frame(width: SIDEBAR_ITEM_ICON_LENGTH,
                   height: SIDEBAR_ITEM_ICON_LENGTH)
            .padding(4)
            .contentShape(Rectangle())
            .onTapGesture {
                log("SidebarListItemSelectionCircleView: tapCallback")
                // ie What kind of selection did we have?
                // - if item was already 100% selected, then deselect
                // - if was 80% or 0% selected, then 100% select
                switch selection {
                case .primary:
                    dispatch(SidebarItemDeselected(id: id))
                case .secondary, .none:
                    dispatch(SidebarItemSelected(id: id))
                }
            }
    }
}
