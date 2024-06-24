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

    @ObservedObject var gestureViewModel: SidebarItemGestureViewModel
    
    var body: some View {
        UIKitTappableWrapper(tapCallback: {
            if let action = action {
                dispatch(action)
            }
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
            Image(systemName: sfImageName).padding()
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
