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
    
    // white when layer is non-edit-mode selected; else determined by primary vs secondary selection status
    let color: Color

    let isHidden: Bool
    
    var body: some View {

        let rotationZ: CGFloat = isClosed ? 0 : 90

        Image(systemName: CHEVRON_GROUP_TOGGLE_ICON)
//            .frame(width: 8, height: 11)
            .foregroundColor(color)
            .rotation3DEffect(Angle(degrees: rotationZ),
                              axis: (x: 0, y: 0, z: rotationZ))
            .padding(2)
//            .frame(width: 20, height: 20) // bigger hit area
            .frame(width: 16, height: 20) // bigger hit area
            .border(.green)
            .contentShape(Rectangle())
            .onTapGesture {
                if isClosed {
                    dispatch(SidebarListItemGroupOpened(openedParent: parentId))
                } else {
                    dispatch(SidebarListItemGroupClosed(closedParentId: parentId))
                }
            }
            .animation(.linear, value: rotationZ)
    }
}

