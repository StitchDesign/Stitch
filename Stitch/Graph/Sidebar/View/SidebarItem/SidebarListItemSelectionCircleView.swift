//
//  _SidebarListItemSelectionCircleView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI
import StitchSchemaKit

struct SidebarListItemSelectionCircleView<Item>: View where Item: SidebarItemSwipable {
    
    private let SELECTION_CIRCLE_SELECTED = "circle.inset.filled"
    private let SELECTION_CIRCLE = "circle"

    @Bindable var item: Item
    
    // white when layer is non-edit-mode selected; else determined by primary vs secondary selection status
    let fontColor: Color
    let isBeingEdited: Bool
        
    var iconName: String {
        item.isSelected
              ? self.SELECTION_CIRCLE_SELECTED
              : self.SELECTION_CIRCLE
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
            .foregroundColor(fontColor)
            .frame(width: SIDEBAR_ITEM_ICON_LENGTH,
                   height: SIDEBAR_ITEM_ICON_LENGTH)
            .padding(4)
            .contentShape(Rectangle())
        
        // simultaneous needed to fix issues where SidebarListGestureRecognizer's
        // tap gesturecancels touches
            .simultaneousGesture(TapGesture().onEnded {
                log("SidebarListItemSelectionCircleView: tapCallback")
                // ie What kind of selection did we have?
                // - if item was already 100% selected, then deselect
                // - if was 80% or 0% selected, then 100% select
                switch item.selectionStatus {
                case .primary:
                    item.didUnselectOnEditMode()
                case .secondary, .none:
                    item.didSelectOnEditMode()
                }
            })
    }
}
