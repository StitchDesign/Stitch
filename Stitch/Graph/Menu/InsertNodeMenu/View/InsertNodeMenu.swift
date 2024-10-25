//
//  InsertNodeMenu.swift
//  Stitch
//
//  Created by cjc on 1/21/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// let INSERT_NODE_MENU_WIDTH: CGFloat = 700
let INSERT_NODE_MENU_WIDTH: CGFloat = 639

// TODO: put menu ABOVE navbar, so that we don't have to shrink for iPad's fullscreen keyboard?
// TODO: if still shrinking, determine the min height dynamically by the diff screen's regular vs height with fullscreen keyboard
// let INSERT_NODE_MENU_MIN_HEIGHT: CGFloat = 220 // previously
let INSERT_NODE_MENU_MIN_HEIGHT: CGFloat = 232 // acceptable for iPad Mini
// let INSERT_NODE_MENU_MIN_HEIGHT: CGFloat = 240 // too big for iPad Mini
// let INSERT_NODE_MENU_MIN_HEIGHT: CGFloat = 260

// let INSERT_NODE_MENU_MAX_HEIGHT: CGFloat = 500
let INSERT_NODE_MENU_MAX_HEIGHT: CGFloat = 366

let INSERT_NODE_MENU_FOOTER_WIDTH: CGFloat = 639
let INSERT_NODE_MENU_FOOTER_HEIGHT: CGFloat = 57

let INSERT_NODE_MENU_SEARCH_RESULTS_WIDTH: CGFloat = 170
let INSERT_NODE_MENU_DESCRIPTION_WIDTH: CGFloat = 460

let INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_WIDTH: CGFloat = 163
let INSERT_NODE_MENU_SEARCH_RESULTS_BUTTON_HEIGHT: CGFloat = 25

let INSERT_NODE_MENU_SCROLL_LIST_BOTTOM_PADDING: CGFloat = INSERT_NODE_MENU_FOOTER_HEIGHT + 8


struct InsertNodeMenuView: View {
    @Environment(StitchStore.self) private var store
    @Environment(\.appTheme) var theme

    @Binding var cornerRadius: CGFloat

    let insertNodeMenuState: InsertNodeMenuState
    let isPortraitMode: Bool
    let showMenu: Bool

    let menuHeight: CGFloat

    @State var footerRect: CGRect = .zero

    let animatingNodeOpacity: CGFloat

    var body: some View {
        sheetView
            .frame(width: InsertNodeMenuWrapper.menuWidth,
                   height: menuHeight)
            .cornerRadius(cornerRadius)
    }

    @MainActor
    var sheetView: some View {
        VStack(spacing: 0) {
            InsertNodeMenuSearchBar()

            HStack(spacing: .zero) {

                InsertNodeMenuSearchResults(
                    searchResults: insertNodeMenuState.searchResults,
                    activeSelection: insertNodeMenuState.activeSelection,
                    footerRect: self.$footerRect,
                    show: store.currentDocument?.graphUI.insertNodeMenuState.show ?? false,
                    animatingNodeOpacity: animatingNodeOpacity)
                    //                    .frame(width: 170, height: 300) // Figma
                    .frame(width: INSERT_NODE_MENU_SEARCH_RESULTS_WIDTH)
                //                    .compositingGroup() // added

                InsertNodeMenuNodeDescriptionView(
                    activeSelection: insertNodeMenuState.activeSelection)
                    //                    .frame(width: 460, height: 300) // Figma
                    .frame(width: INSERT_NODE_MENU_DESCRIPTION_WIDTH)
            } // HStack
            .overlay(alignment: .bottom) {
                footerView
            }
        } // VStack
        .background(INSERT_NODE_SEARCH_BACKGROUND.opacity(1 - animatingNodeOpacity))
        .foregroundColor(INSERT_NODE_MENU_SEARCH_TEXT)
        // Important: animates the entire view's appearance at same time; otherwise e.g. the frosted background fades in separately
        .compositingGroup()
    }

    @MainActor
    var footerView: some View {
        HStack {
            Spacer()
            StitchButton(action: {
                dispatch(AddNodeButtonPressed())
            }, label: {
                Text("Add Node")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .padding(8)
                    .background(theme.themeData.edgeColor.opacity(1 - animatingNodeOpacity))
                    .cornerRadius(8)
            })
        }
        .padding([.leading, .trailing], 12)
        .padding([.top, .bottom], 8)
        .frame(width: INSERT_NODE_MENU_FOOTER_WIDTH,
               height: INSERT_NODE_MENU_FOOTER_HEIGHT)
        .background(InsertNodeFooterSizeReader(footerRect: $footerRect))
        .background(.ultraThinMaterial)
    }
}

struct InsertNodeMenu_Previews: PreviewProvider {
    // @Namespace static var mockNamespace
    @State static var isCreatingNode = false

    static var previews: some View {
        ZStack {
            InsertNodeMenuView(cornerRadius: .constant(20),
                               insertNodeMenuState: .init(),
                               isPortraitMode: false,
                               showMenu: true,
                               menuHeight: INSERT_NODE_MENU_MAX_HEIGHT,
                               animatingNodeOpacity: 0.0)
        }
        .previewDevice("iPad mini (6th generation)")
    }
}
