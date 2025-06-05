//
//  InsertNodeMenu.swift
//  Stitch
//
//  Created by cjc on 1/21/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import TipKit


let INSERT_NODE_MENU_ADD_NODE_BUTTON_COLOR: Color = Color(uiColor: UIColor(hex: "F3F3F3")!)

// let INSERT_NODE_MENU_WIDTH: CGFloat = 700
let INSERT_NODE_MENU_WIDTH: CGFloat = 639

// TODO: put menu ABOVE navbar, so that we don't have to shrink for iPad's fullscreen keyboard?
// TODO: if still shrinking, determine the min height dynamically by the diff screen's regular vs height with fullscreen keyboard
// let INSERT_NODE_MENU_MIN_HEIGHT: CGFloat = 220 // previously
// let INSERT_NODE_MENU_MIN_HEIGHT: CGFloat = 232 // acceptable for iPad Mini
// let INSERT_NODE_MENU_MIN_HEIGHT: CGFloat = 240 // too big for iPad Mini
// let INSERT_NODE_MENU_MIN_HEIGHT: CGFloat = 260
let INSERT_NODE_MENU_MIN_HEIGHT: CGFloat = 280 // okay now that node menu sits above sidebar

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
    @AppStorage(StitchAppSettings.APP_THEME.rawValue) private var theme: StitchTheme = StitchTheme.defaultTheme
    @AppStorage(StitchAppSettings.CAN_SHARE_AI_DATA.rawValue) private var canShareAIData: Bool?
    
    @State private var showAILogsAlert = false
    @State private var showDataCollectionPopover = false
    @State private var footerRect: CGRect = .zero
    @State private var isLoadingStitchAI = false
    @State private var queryString = ""
    
    private let launchTip = StitchAILaunchTip()

    @Bindable var document: StitchDocumentViewModel
    
    let insertNodeMenuState: InsertNodeMenuState
    let isPortraitMode: Bool
    let showMenu: Bool
    let menuHeight: CGFloat
    
    var body: some View {
        sheetView
        // MARK: uncomment lines below to debug AI logs alert
//            .onAppear {
//                self.canShareAIData = nil
//            }
        
        // these are now mostly static?
        // except menuHeight can change on iPad?
            .frame(width: InsertNodeMenuWithModalBackground.menuWidth,
                   height: menuHeight)
        
            .cornerRadius(InsertNodeMenuWithModalBackground.shownMenuCornerRadius)
        // Background view guarantees focus state for search bar
            .background {
                TipView(self.launchTip, arrowEdge: .top)
                    .width(400)
                    .fixedSize()
                    .offset(y: (menuHeight / 2) + 64)
            }
            .alert(isPresented: $showAILogsAlert) {
                Alert(
                    title: Text("Help Improve Stitch AI"),
                    message: Text("To keep Stitch AI faster and smarter for you, we’ll collect a tiny amount of anonymous usage data. You can switch this off anytime in App Settings."),
                    primaryButton: .default(
                        Text("Start Using Stitch AI"),
                        action: {
                            self.canShareAIData = true
                            dispatch(SubmitUserPromptToOpenAI(prompt: queryString))
                        }
                    ),
                    secondaryButton: .default(
                        Text("Learn More"),
                        action: {
                            // Set to true so that alert only appears once
                            self.canShareAIData = true
                            self.showDataCollectionPopover = true
                        }
                    )
                )
            }
            .popover(isPresented: $showDataCollectionPopover) {
                VStack(alignment: .leading) {
                    StitchDocsPopoverView(router: .overview(.dataCollection))
                    
                    Text("Control in App Settings.")
                        .padding([.horizontal, .bottom])
                        .foregroundColor(theme.themeData.edgeColor)
                        .onTapGesture {
                            store.alertState.showAppSettings = true
                        }
                }
            }
    }

    var isGeneratingAINode: Bool {
       document.insertNodeMenuState.isGeneratingAIResult
    }
    
    @MainActor
    var sheetView: some View {
        VStack(spacing: 0) {
            InsertNodeMenuSearchBar(launchTip: self.launchTip,
                                    isLoadingStitchAI: $isLoadingStitchAI,
                                    queryString: $queryString,
                                    userSubmitted: userSubmitted)
            
            if !isGeneratingAINode {
                HStack(spacing: .zero) {
                    // alternatively, change the height available for this?
                    
                    InsertNodeMenuSearchResults(
                        searchResults: insertNodeMenuState.searchResults,
                        activeSelection: insertNodeMenuState.activeSelection,
                        footerRect: self.$footerRect,
                        show: document.insertNodeMenuState.show)
                    //                    .frame(width: 170, height: 300) // Figma
                    .frame(width: INSERT_NODE_MENU_SEARCH_RESULTS_WIDTH)
                    
                    InsertNodeMenuNodeDescriptionView(
                        activeSelection: insertNodeMenuState.activeSelection)
                    //                    .frame(width: 460, height: 300) // Figma
                    .frame(width: INSERT_NODE_MENU_DESCRIPTION_WIDTH)
                } // HStack

                // Note: let contents overflow; do not use padding
                // .padding(.bottom, 8)

                .transition(.move(edge: .top))
            }
        } // VStack
        .background(INSERT_NODE_SEARCH_BACKGROUND)
        .animation(.stitchAnimation, value: self.isLoadingStitchAI)
        .foregroundColor(INSERT_NODE_MENU_SEARCH_TEXT)
        .cornerRadius(InsertNodeMenuWithModalBackground.shownMenuCornerRadius)
        
        // Important: animates the entire view's appearance at same time; otherwise e.g. the frosted background fades in separately
        .compositingGroup()
        
        // Add onDisappear to cancel any in-progress request
        .onDisappear {
            // Only cancel if not auto-hiding
            if !document.insertNodeMenuState.isAutoHiding {
                document.aiManager?.cancelCurrentRequest()
                document.insertNodeMenuState.isGeneratingAIResult = false
            }
            // Reset the flag
            document.insertNodeMenuState.isAutoHiding = false
        }
    }
    
    var isAIMode: Bool {
        self.document.aiManager.isDefined && self.insertNodeMenuState.isAIMode
    }
    
    func handleAIQuery() {
        // User hasn't opted in or out if logs setting is nil
        let hasUserAcknolwedgedDataCollection = self.canShareAIData != nil
        
        guard hasUserAcknolwedgedDataCollection else {
            self.showAILogsAlert = true
            return
        }
        
        dispatch(SubmitUserPromptToOpenAI(prompt: queryString))
    }
    
    func userSubmitted() {
        if self.isAIMode {
            // Invalidate tip in future once AI submission is completed
            self.launchTip.invalidate(reason: .actionPerformed)
            
            self.isLoadingStitchAI = true
            
            self.handleAIQuery()
        } else if (self.store.currentDocument?.insertNodeMenuState.activeSelection).isDefined {
            dispatch(AddNodeButtonPressed())
        }
    }

    @MainActor
    var footerView: some View {
        HStack {
            #if STITCH_AI_REASONING
            Text("Model: \(document.aiManager?.secrets.openAIModel ?? "None")")
            #endif
            Spacer()
            StitchButton(action: {
                if isAIMode {
                    if let query = document.insertNodeMenuState.searchQuery {
                        dispatch(SubmitUserPromptToOpenAI(prompt: query))
                    }
                } else {
                    dispatch(AddNodeButtonPressed())
                }
            }, label: {
                let isLoading = document.insertNodeMenuState.isGeneratingAIResult
                
                HStack(spacing: 8) {
                    StitchTextView(string: isAIMode ? "Submit Prompt" : "Add Node",
                                   fontColor: INSERT_NODE_MENU_ADD_NODE_BUTTON_COLOR)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(INSERT_NODE_MENU_ADD_NODE_BUTTON_COLOR)
                    }
                }
                .padding(8)
                .background(theme.themeData.edgeColor)
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
            InsertNodeMenuView(document: .createEmpty(),
                               insertNodeMenuState: .init(),
                               isPortraitMode: false,
                               showMenu: true,
                               menuHeight: INSERT_NODE_MENU_MAX_HEIGHT)
        }
        .previewDevice("iPad mini (6th generation)")
    }
}
