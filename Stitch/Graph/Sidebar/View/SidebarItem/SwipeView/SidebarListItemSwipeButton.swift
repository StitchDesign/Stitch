//
//  SidebarListItemSwipeButton.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SidebarListItemSwipeButton: View {
    var action: Action?
    let sfImageName: String
    let backgroundColor: Color
    var willLeftAlign: Bool = false

//    @ObservedObject var gestureViewModel: SidebarItemGestureViewModel
    @ObservedObject var gestureViewModel: SidebarItemGestureViewModel
    
    var body: some View {
//        UIKitTappableWrapper(tapCallback: {
//            if let action = action {
//                dispatch(action)
//            }
//            withAnimation {
//                gestureViewModel.resetSwipePosition()
//            }
//        },
//                             view: {
//            buttonView
//        })
        
//        UIKitTappableWrapper(tapCallback: {
//            if let action = action {
//                dispatch(action)
//            }
//            withAnimation {
//                gestureViewModel.resetSwipePosition()
//            }
//        },
//                             view: {
//            buttonView
//        })
       
        buttonView
            .border(.black, width: 4)
        
//        Button(action: {
//            if let action = action {
//                dispatch(action)
//            }
//            withAnimation {
//                gestureViewModel.resetSwipePosition()
//            }
//        },
//               label: {
//            buttonView
//        })
//        
//        .cornerRadius(1)
//        .buttonStyle(.borderless)
    }

    private var buttonView: some View {
        HStack {
            Image(systemName: sfImageName)
//                .resizable()
//                .scaledToFit()
                .frame(width: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT,
                       height: SIDEBAR_LIST_ITEM_ICON_AND_TEXT_AREA_HEIGHT)
            
//            if willLeftAlign {
//                Spacer()
//            }
        }
        .foregroundColor(.white)
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
//        .background(backgroundColor)
        .background(backgroundColor)
        .onTapGesture {
            if let action = action {
                dispatch(action)
            }
        }
//        .animation(.stitchAnimation(duration: 0.25), value: willLeftAlign)
        
    }
}
