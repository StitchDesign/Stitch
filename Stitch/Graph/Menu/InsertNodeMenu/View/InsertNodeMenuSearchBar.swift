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
let INSERT_NODE_MENU_SEARCH_BAR_BUTTON_HEIGHT: CGFloat = 24
let AI_THINKING_TEXT: String = "Thinking..."

struct InsertNodeMenuSearchBar: View {
    /*
     Note: Nick encountered an interesting case where the onSubmit callback (i.e. Enter key pressed) would have an activeSelection out of date with the actual search-bar's contents.
     (In contrast, pressing the add-node button in the UI was fine.)
     In the past we've passed activeSelection to the action, rather than having the action pull activeSelection from state in its handler, to facilitate redo-events.
     Post-versioning redo events seem largely broken; but maybe it's safer to keep what we had?
     So we now access the activeSelection from the same source, `@Environment(StitchStore.self)`, in both InsertNodeMenuView and InsertNodeMenuSearchBar.
     */
    
    @AppStorage(StitchAppSettings.APP_THEME.rawValue) private var theme: StitchTheme = .defaultTheme
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    @Bindable var document: StitchDocumentViewModel
    let launchTip: StitchAILaunchTip
    @Binding var queryString: String
    let userSubmitted: () -> Void

    var isLoadingAIResult: Bool {
        document.isLoadingAI
    }
    
    private var lightModeShimmerConfig: CustomShimmerConfig {
        CustomShimmerConfig(
            tint: .white.opacity(0.15),
            highlight: .white,
            blur: 5
        )
    }
    
    // TODO: this logic is a bit awkward when stream completes; we switch from the non-empty thinking-stream to the (empty?) query string; really, we need to consolidate "should the menu be open?" logic across regular
    private var displayText: String {
        if isLoadingAIResult || document.isStreamingResponses || !document.streamingReasoningText.isEmpty {
//            return document.streamingReasoningText
         return document.streamingReasoningText.isEmpty ? AI_THINKING_TEXT : document.streamingReasoningText
        }
        return queryString
    }
        
    var body: some View {
        let searchInput = VStack(spacing: .zero) {
            ZStack(alignment: .leading) {
                if document.isStreamingResponses {
                    // `.contentTransition` only works on Text view, not TextField view
                    Text(displayText)
                        .contentTransition(.numericText())
                        .animation(.default, value: displayText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                        .padding(.trailing, 60) // to keep text from running below the progress view
                        .padding(.trailing, 28) // to keep text from running below the cancel button
                        .font(.system(size: 24))
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                        .modifier(HybridShimmerModifier(colorScheme: colorScheme, lightModeConfig: lightModeShimmerConfig))
                    
                    // TODO: could instead use HStack { Text; Spacer; Button; ProgressView }, but
                        .overlay(alignment: .center) {
                            HStack {
                                Spacer()
                                Button {
                                    // Cancel streaming
                                    document.aiManager?.cancelCurrentRequest()
                                    document.insertNodeMenuState.show = false
                                } label: {
                                    Image(systemName: "stop.circle")
                                        .resizable()
                                        .frame(width: INSERT_NODE_MENU_SEARCH_BAR_BUTTON_HEIGHT,
                                               height: INSERT_NODE_MENU_SEARCH_BAR_BUTTON_HEIGHT)
                                }
                                .padding(.trailing, 8)
                                .buttonStyle(.borderless)
                                
                                ProgressView()
                                    .scaleEffect(1.5)
                            }
                            .padding(.trailing, 20)
                        }
                } else {
                    // Show TextField when not streaming for input
                    TextField("Search or enter AI prompt...", text: $queryString)
                        .focused($isFocused)
                        .padding(.leading, 16)
                        .padding(.trailing, 60)
                        .font(.system(size: 24))
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .disableAutocorrection(true)
                        .onSubmit {
                            self.userSubmitted()
                        }
                        .onAppear {
                             // log("InsertNodeMenuSearchBar: onAppear: inner")
                            self.queryString = ""
                            self.isFocused = true

                            // Hack: additional focus-setting after a slight delay; it seems that StitchHostingController contributes to the field being sometimes defocused after .onAppear
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                                // log("InsertNodeMenuSearchBar: onAppear: inner: callback")
                                self.isFocused = true
                            }
                        }
                        .overlay(alignment: .center) {
                            HStack {
                                Spacer()
                                Button(action: {
                                    // Helps to defocus the .focusedValue, ensuring our shortcuts like "CMD+A Select All" is enabled again.
                                    self.isFocused = false
                                    
                                    self.userSubmitted()
                                }, label: {
                                    Image(systemName: "plus.app")
                                        .resizable()
                                        .frame(width: INSERT_NODE_MENU_SEARCH_BAR_BUTTON_HEIGHT,
                                               height: INSERT_NODE_MENU_SEARCH_BAR_BUTTON_HEIGHT)
                                })
                                .padding(.trailing, 8)
                                .buttonStyle(.borderless)
                            }
                            .padding(.trailing, 20)
                        }
                }
            }
        }
        // We apparently need both `.onAppear`'s to set .isFocused = true ?
        // Note: do not wipe queryString in .onChange(of: self.isFocused), otherwise we lose the user's string when user switches back to the Stitch window in Catalyst.
        .onAppear {
            // log("InsertNodeMenuSearchBar: onAppear: outer")
            self.isFocused = true
        }
        .onChange(of: queryString) {
            dispatch(InsertNodeQuery(query: queryString))
        }
        // Note: .onDisappear has a noticeable delay, so relying on it to clear the search-query won't work if user rapidly re-opens the menu.
        .onChange(of: document.insertNodeMenuState.show) { _, newValue in
            if newValue {
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

#Preview {
    InsertNodeMenuSearchBar(document: .createEmpty(),
                            launchTip: StitchAILaunchTip(),
                            queryString: .constant("testing")) {
        print("nothing")
    }
}
