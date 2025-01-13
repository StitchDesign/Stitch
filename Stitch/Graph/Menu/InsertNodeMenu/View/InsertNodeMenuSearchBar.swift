//
//  InsertNodeMenuSearchBar.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/21/22.
//

import SwiftUI
import Combine
import UIKit
import GameController

let INSERT_NODE_MENU_SEARCH_BAR_HEIGHT: CGFloat = 68

struct InsertNodeMenuSearchBar: View {
    /*
     Note: Nick encountered an interesting case where the onSubmit callback (i.e. Enter key pressed) would have an activeSelection out of date with the actual search-bar's contents.
     (In contrast, pressing the add-node button in the UI was fine.)
     In the past we've passed activeSelection to the action, rather than having the action pull activeSelection from state in its handler, to facilitate redo-events.
     Post-versioning redo events seem largely broken; but maybe it's safer to keep what we had?
     So we now access the activeSelection from the same source, `@Environment(StitchStore.self)`, in both InsertNodeMenuView and InsertNodeMenuSearchBar.
     */
    @Environment(StitchStore.self) private var store
    
    @State private var queryString = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        let searchInput = VStack(spacing: .zero) {
            TextField("Search or enter AI prompt...", text: $queryString)
                .focused($isFocused)
                .frame(height: INSERT_NODE_MENU_SEARCH_BAR_HEIGHT)
                .padding(.leading, 52)
                .padding(.trailing, 12)
                .overlay(HStack {
                    #if STITCH_AI
                    let isAIMode = store.currentDocument?.graphUI.insertNodeMenuState.isAIMode ?? false
                    Image(systemName: isAIMode ? "sparkles" : "magnifyingglass")
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 15)
                    #else
                    Image(systemName: "magnifyingglass")
                        .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 15)
                    #endif
                })
                .font(.system(size: 24))
                .disableAutocorrection(true)
                .onSubmit {
                    #if STITCH_AI
                    let isAIMode = store.currentDocument?.graphUI.insertNodeMenuState.isAIMode ?? false
                    if isAIMode && FeatureFlags.USE_AI_MODE {
                        dispatch(GenerateAINode(prompt: queryString))
                    } else if (self.store.currentDocument?.graphUI.insertNodeMenuState.activeSelection) != nil {
                        dispatch(AddNodeButtonPressed())
                    }
                    #else
                    if (self.store.currentDocument?.graphUI.insertNodeMenuState.activeSelection) != nil {
                        dispatch(AddNodeButtonPressed())
                    }
                    #endif

                    // Helps to defocus the .focusedValue, ensuring our shortcuts like "CMD+A Select All" is enabled again.
                    self.isFocused = false
                }
                .onAppear {
                     // log("InsertNodeMenuSearchBar: onAppear: inner")
                    self.queryString = ""
                    self.isFocused = true

                    // Hack: additional focus-setting after a slight delay; it seems that StitchHostingController contributes to the field being sometimes defocused after .onAppear
                    //                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                        // log("InsertNodeMenuSearchBar: onAppear: inner: callback")
                        self.isFocused = true
                    }
                }
        }
        // we apparently need both `.onAppear`'s to set .isFocused = true ?
        // Note: do not wipe queryString in .onChange(of: self.isFocused), otherwise we lose the user's string when user switches back to the Stitch window in Catalyst.
        .onAppear {
            // log("InsertNodeMenuSearchBar: onAppear: outer")
            self.isFocused = true
        }
        .onChange(of: queryString) {
            dispatch(InsertNodeQuery(query: queryString))
        }
        // Note: .onDisappear has a noticeable delay, so relying on it to clear the search-query won't work if user rapidly re-opens the menu.
        .onChange(of: self.store.currentDocument?.graphUI.insertNodeMenuState.show) { _, newValue in
            if let newValue = newValue, newValue {
                self.queryString = ""
                // added
                self.isFocused = true
            }
        }
        // Keep redux state in-sync
        .onChange(of: isFocused) { oldValue, newValue in
            // log("InsertNodeMenuSearchBar: on change of isFocused: newValue: \(newValue)")
            if newValue {
                dispatch(ReduxFieldFocused(focusedField: .insertNodeMenu))
            } else {
                dispatch(ReduxFieldDefocused(focusedField: .insertNodeMenu))
            }
        }

        // Hosting controller needed to register arrow key presses in this view;
        // this is also the main key-press listener for the app, since the insert node menu is always on-screen
        StitchHostingControllerView(ignoreKeyCommands: false,
                                    inputTextFieldFocused: false, // N/A
                                    usesArrowKeyBindings: true, // N/A ?
                                    name: .insertNodeMenuSearchbar) {
            searchInput
        }
        .height(INSERT_NODE_MENU_SEARCH_BAR_HEIGHT) // need to set height again

    }
}
