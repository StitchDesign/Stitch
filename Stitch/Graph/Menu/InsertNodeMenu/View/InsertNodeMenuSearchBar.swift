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
import Shimmer

let INSERT_NODE_MENU_SEARCH_BAR_HEIGHT: CGFloat = 68

// MARK: - Custom Shimmer Effect (for Light Mode)

// Shimmer Config
struct CustomShimmerConfig {
    var tint: Color
    var highlight: Color
    var blur: CGFloat = 0
    var highlightOpacity: CGFloat = 1
    var speed: CGFloat = 2
}

struct CustomShimmerEffectHelper: ViewModifier {
    // Shimmer Config
    var config: CustomShimmerConfig
    // Animation Properties
    @State private var moveTo: CGFloat = -0.7
    
    func body(content: Content) -> some View {
        content
        // Adding Shimmer Animation with the help of Masking Modifier
            .overlay {
                // Changing Tint Color
                Rectangle()
                    .fill(config.tint)
                    .mask {
                        content
                    }
                    .overlay {
                        // Shimmer
                        GeometryReader {
                            let size = $0.size
                            let extraOffset = size.height / 2.5
                            
                            Rectangle()
                                .fill(config.highlight)
                                .mask {
                                    Rectangle()
                                    // Gradient For Glowing at the Center
                                        .fill(
                                            .linearGradient(colors: [
                                                .white.opacity(0),
                                                config.highlight.opacity(config
                                                    .highlightOpacity),
                                                .white.opacity(0)
                                            ], startPoint: .top, endPoint: .bottom)
                                        )
                                }
                            // Adding Blur
                                .blur(radius: config.blur)
                            // Rotating (Degree: Your Choice of Wish)
                                .rotationEffect(.init(degrees: -70))
                            // Moving to the Start
                                .offset(x: moveTo > 0 ? extraOffset : -extraOffset)
                                .offset(x: size.width * moveTo)
                        }
                    }
                    .mask {
                        content
                    }
            }
        // Animating Movement
            .onAppear {
                DispatchQueue.main.async {
                    moveTo = 0.7
                }
            }
            .animation(.linear(duration: config.speed).repeatForever(autoreverses: false), value: moveTo)
    }
}

extension View {
    @ViewBuilder
    func customShimmer(_ config: CustomShimmerConfig) -> some View {
        self
            .modifier(CustomShimmerEffectHelper(config: config))
    }
}

// MARK: - Hybrid Shimmer Modifier

struct HybridShimmerModifier: ViewModifier {
    let colorScheme: ColorScheme
    let lightModeConfig: CustomShimmerConfig
    
    func body(content: Content) -> some View {
        switch colorScheme {
        case .dark:
            // Use SwiftUI-Shimmer package for dark mode with matching duration
            content.shimmering(duration: lightModeConfig.speed)
        case .light:
            // Use custom shimmer for light mode
            content.customShimmer(lightModeConfig)
        @unknown default:
            // Fallback to light mode behavior
            content.customShimmer(lightModeConfig)
        }
    }
}

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
    
    private var displayText: String {
        if document.isStreamingResponses {
            return document.streamingReasoningText.isEmpty ? "Thinking..." : document.streamingReasoningText
        }
        return queryString
    }
    
    var rightSideButton: some View {
        HStack {
            Group {
                if isLoadingAIResult {
                    HStack {
                        Button {
                            document.aiManager?.cancelCurrentRequest()
                            document.insertNodeMenuState.show = false
                        } label: {
                            Image(systemName: "stop.circle")
                        }
                        .padding(.trailing, 4)
                        .scaleEffect(1.5)
                        .buttonStyle(.borderless)
                        
                        
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(STITCH_TITLE_FONT_COLOR)
                    }
                    
                } else {
                    Button(action: {
                        // Helps to defocus the .focusedValue, ensuring our shortcuts like "CMD+A Select All" is enabled again.
                        self.isFocused = false
                        
                        self.userSubmitted()
                    }, label: {
                        Image(systemName: "plus.app")
                    })
//                    .frame(width: 54, height: 54)
                    .scaleEffect(1.5)
                    .buttonStyle(.borderless)
                }
            } // Group
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 20)
            .animation(.linear(duration: 0.2), value: isLoadingAIResult)
        }
    }
    
    var body: some View {
        let searchInput = VStack(spacing: .zero) {
            ZStack(alignment: .leading) {
                if document.isStreamingResponses {
                    // Show Text view when streaming for `.contentTransition`
                    Text(displayText)
                        .contentTransition(.numericText())
                        .animation(.default, value: displayText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                        .padding(.trailing, 60)
                        .font(.system(size: 24))
                        .multilineTextAlignment(.leading)
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                        .modifier(HybridShimmerModifier(colorScheme: colorScheme, lightModeConfig: lightModeShimmerConfig))
                        .overlay(alignment: .center) {
                            HStack {
                                Spacer()
                                Button {
                                    // Cancel streaming
                                    document.aiManager?.cancelCurrentRequest()
                                    document.insertNodeMenuState.show = false
                                } label: {
                                    Image(systemName: "stop.circle")
                                }
                                .padding(.trailing, 8)
                                .scaleEffect(1.75)
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
                                })
                                .padding(.trailing, 8)
                                .scaleEffect(1.75)
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
