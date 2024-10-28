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

struct SidebarListItemChevronView<SidebarViewModel>: View where SidebarViewModel: ProjectSidebarObservable {
    let sidebarViewModel: SidebarViewModel
    let item: SidebarViewModel.ItemViewModel
    
    // white when layer is non-edit-mode selected; else determined by primary vs secondary selection status
    let fontColor: Color

    var isClosed: Bool {
        item.isCollapsedGroup
    }
    
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
        
            .foregroundColor(fontColor)
            .rotation3DEffect(Angle(degrees: rotationZ),
                              axis: (x: 0, y: 0, z: rotationZ))
                
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture()
                    .onEnded {
                        if isClosed {
                            sidebarViewModel.sidebarListItemGroupOpened(parentItem: item)
                        } else {
                            sidebarViewModel.sidebarListItemGroupClosed(closedParent: item)
                        }
                    }
            )
            .animation(.linear, value: rotationZ)
    }
}

