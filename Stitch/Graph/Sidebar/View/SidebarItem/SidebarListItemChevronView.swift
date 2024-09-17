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
    
    var rotationZ: CGFloat {
        isClosed ? 0 : 90
    }
    
    var body: some View {

        Image(systemName: CHEVRON_GROUP_TOGGLE_ICON)
            .resizable()
            .scaledToFit()
        
        #if targetEnvironment(macCatalyst)
            .padding(4)
            .padding(.horizontal, 2)
        #else
            .padding(4)
            .padding(.horizontal, 4)
        #endif
        
            .frame(width: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT,
                   height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
        
            .foregroundColor(color)
            .rotation3DEffect(Angle(degrees: rotationZ),
                              axis: (x: 0, y: 0, z: rotationZ))
                
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

