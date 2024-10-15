//
//  SidebarListItemSwipeButton.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeButton<Item: SidebarItemSwipable>: View {
    let sfImageName: String
    let backgroundColor: Color
    var willLeftAlign: Bool = false

    @Bindable var gestureViewModel: Item
    
    let action: @MainActor () -> Void
    
    var body: some View {
        UIKitTappableWrapper(tapCallback: {
            action()
            
            withAnimation {
                gestureViewModel.resetSwipePosition()
            }
        },
                             view: {
            buttonView
        })
        .cornerRadius(1)
        .buttonStyle(.borderless)
    }

    private var buttonView: some View {
        HStack {
            Image(systemName: sfImageName)
                .resizable()
                .scaledToFit()
                .frame(width: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT,
                       height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
            
            if willLeftAlign {
                Spacer()
            }
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .animation(.stitchAnimation(duration: 0.25), value: willLeftAlign)
    }
}
