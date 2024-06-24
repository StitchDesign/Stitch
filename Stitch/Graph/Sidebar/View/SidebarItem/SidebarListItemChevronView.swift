//
//  _SidebarListItemChevronView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/8/24.
//

import SwiftUI

import StitchSchemaKit

// group closed; rotated 90 degrees to be 'group open'
let CHEVRON_GROUP_TOGGLE_ICON =  "chevron.right"

struct SidebarListItemChevronView: View {

    let isClosed: Bool
    let parentId: LayerNodeId
    let selection: SidebarListItemSelectionStatus
    let isHidden: Bool

    var color: Color {
        selection.color(isHidden)
    }
    
    var body: some View {

        let rotationZ: CGFloat = isClosed ? 0 : 90

        Image(systemName: CHEVRON_GROUP_TOGGLE_ICON)
            .foregroundColor(color)
            .rotation3DEffect(Angle(degrees: rotationZ),
                              axis: (x: 0, y: 0, z: rotationZ))
            .frame(width: SIDEBAR_ITEM_ICON_LENGTH,
                   height: SIDEBAR_ITEM_ICON_LENGTH)
            .padding(4)
            .contentShape(Rectangle())
            .onTapGesture {
                if isClosed {
                    dispatch(SidebarListItemGroupOpened(openedParent: parentId))
                } else {
                    dispatch(SidebarListItemGroupClosed(closedParentId: parentId))
                }
            }
            .animation(.linear, value: rotationZ)
            .animation(.linear, value: color)
    }
}

