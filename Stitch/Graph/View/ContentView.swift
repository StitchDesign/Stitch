//
//  ContentView.swift
//  prototype
//
//  Created by cjc on 11/1/20.
//

import SwiftUI
import StitchSchemaKit

/* ----------------------------------------------------------------
 CONTENT VIEW
 ---------------------------------------------------------------- */

struct ContentView: View, KeyboardReadable {
    @State private var menuHeight: CGFloat = INSERT_NODE_MENU_MAX_HEIGHT
    
    // Controlled by a GeometryReader that respects keyboard safe-area,
    // so that menuOrigin respects actual height of screen
    // (which is smaller when full-screen keyboard is on-screen).
    @State private var screenSize: CGSize = .zero
    
    @Namespace private var graphNamespace
    @StateObject private var showFullScreen = AnimatableBool(false)
    @State private var showFullScreenAnimateCompleted = true
    
    // Controls the animation of newly created node from the insert node menu
    @State private var previewingNodeChoice: InsertNodeMenuOption?

    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel

    let alertState: ProjectAlertState
    let routerNamespace: Namespace.ID
    
    var previewWindowSizing: PreviewWindowSizing {
        self.document.previewWindowSizingObserver
    }

    /// Shows menu wrapper view while node animation takes place
    var showMenu: Bool {
        document.insertNodeMenuState.show
    }

    var nodeAndMenu: some View {
        ZStack {
            
            // Best place to listen for TAB key for flyout
            UIKitWrapper(ignoresKeyCommands: true,
                         inputTextFieldFocused: document.reduxFocusedField?.inputTextFieldWithNumberIsFocused(document.graph) ?? false,
                         name: .mainGraph) {
                contentView // the graph
            }
        }
    }

    var body: some View {
        ZStack {
            
            // probably the best location for listening to how iPad's on-screen keyboard reduces available height for node menu ?
            
            
            // Must respect keyboard safe-area
            ProjectWindowSizeReader(previewWindowSizing: previewWindowSizing,
                                    previewWindowSize: document.previewWindowSize,
                                    isFullScreen: document.isFullScreenMode,
                                    showFullScreenAnimateCompleted: $showFullScreenAnimateCompleted,
                                    showFullScreenObserver: showFullScreen,
//                                    menuHeight: $menuHeight,
                                    menuHeight: menuHeight)

            // Must IGNORE keyboard safe-area
            nodeAndMenu
#if !targetEnvironment(macCatalyst)
                .ignoresSafeArea(edges: showFullScreen.isTrue ? [.all] : [.bottom])
                .ignoresSafeArea([.keyboard])
#endif
        }
       .environment(\.viewframe, document.frame)
       .environment(\.isSelectionBoxInUse, document.visibleGraph.selection.isSelecting)
    }

    @ViewBuilder
    var contentView: some View {
        ZStack {
            
            // ALWAYS show full-screen preview on iPhone.
            // Also, if in full-screen preview mode on Catalyst or iPad, place the fullscreen preview on top.
            if showFullScreen.isTrue || StitchDocumentViewModel.isPhoneDevice {
                fullScreenPreviewView
#if !targetEnvironment(macCatalyst)
                // Fullscreen ALWAYS ignores ALL safe areas
                    .ignoresSafeArea(.all)
#endif
                    
                // for modal background, use preview windw background color + a couple shades darker
                    .background {
                        document.previewWindowBackgroundColor.overlay {
                            Color.black.opacity(0.2)
                        }
                    }
            } // if showFullScreen.isTrue
            
            // NEVER show graph-view on iPhone
            if !StitchDocumentViewModel.isPhoneDevice {
                // Check if we're on iPhone, otherwise the project view will start to render on
                // phone before showFullScreen is set
                ProjectNavigationView(store: store,
                                      document: document,
                                      routerNamespace: routerNamespace)
                .zIndex(showFullScreen.isTrue ? -99 : 0)
                .overlay {
                    StitchProjectOverlayView(document: document,
                                             store: store,
                                             showFullScreen: showFullScreen.isTrue,
                                             graphNamespace: graphNamespace)
                }
//                // Layer Inspector Flyout must sit above preview window
                .overlay {
                    flyout
                }
                .overlay {
                    catalystProjectTitleEditView
                }
                
                // NOTE: APPARENTLY NOT NEEDED ANYMORE?
//                // Note: we want the floating preview window to 'ignore safe areas' (e.g. the keyboard rising up should not affect preview window's size or position):
//                // we must apply the `.ignoresSafeArea` modifier to the ProjectNavigationView, rather than .overlay's contents
//                #if !targetEnvironment(macCatalyst)
//                                .ignoresSafeArea(edges: showFullScreen.isTrue ? [.all] : [.bottom])
//                                .ignoresSafeArea([.keyboard])
//                #endif
            }
        } // ZStack
        
        .stitchSheet(isPresented: alertState.showProjectSettings,
                     titleLabel: "Settings",
                     hideAction: store.hideProjectSettingsSheet) {
            ProjectSettingsView(previewWindowSize: document.previewWindowSize,
                                previewSizeDevice: document.previewSizeDevice,
                                previewWindowBackgroundColor: document.previewWindowBackgroundColor,
                                graph: document.graph,
                                document: document) }
        .modifier(FileImportView(fileImportState: alertState.fileImportModalState))
        .modifier(AnimateCompletionHandler(percentage: showFullScreen.value) {
            // only set this state to true when we're animating into full screen mode
            DispatchQueue.main.async {
                self.showFullScreenAnimateCompleted = true
            }
        })
        .stitchSheet(isPresented: document.llmRecording.promptState.showModal,
                     titleLabel: "LLM Recording",
                     hideAction: document.closedLLMRecordingPrompt,
                     sheetBody: {
            LLMAssignPromptToScratchLLMExampleModalView()
        })
    }

    private var fullScreenPreviewView: some View {
        FullScreenPreviewViewWrapper(
            document: document,
            previewWindowSizing: self.previewWindowSizing,
            showFullScreenPreviewSheet: alertState.showFullScreenPreviewSheet,
            graphNamespace: graphNamespace,
            routerNamespace: routerNamespace,
            animationCompleted: showFullScreenAnimateCompleted)
    }
        
    @ViewBuilder
    var flyout: some View {
        OpenFlyoutView(document: document,
                       graph: document.visibleGraph)
    }
    
    @ViewBuilder
    var catalystProjectTitleEditView: some View {
#if targetEnvironment(macCatalyst)
        if document.showCatalystProjectTitleModal {
            VStack(alignment: .leading) {
                StitchTextView(string: "Edit Project Title")
                CatalystProjectTitleModalView(graph: document.visibleGraph,
                                              document: document)
            }
            .padding()
            .frame(width: 360, alignment: .leading)
            .background(
                Color(uiColor: .systemGray5)
                // NOTE: strangely we need `[.all, .keyboard]` on BOTH the background color AND the StitchHostingControllerView
                    .ignoresSafeArea([.all, .keyboard])
                    .cornerRadius(4)
            )
            .position(
                x: 180 // half width of edit view itself, so its left-edge sits at screen's left-edge
                + 16 // padding
                // + 330 // traffic lifts, sidebar button
                + 158
                + (document.leftSidebarOpen ? (-SIDEBAR_WIDTH/2 + 38) : 0)
                
                , y: 52)
                
        } // if document
#endif
    }
}
