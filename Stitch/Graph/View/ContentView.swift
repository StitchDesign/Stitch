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
    @Bindable var graphUI: GraphUIState

    let alertState: ProjectAlertState
    let routerNamespace: Namespace.ID

    var showPreviewWindow: Bool {
        graphUI.showPreviewWindow
    }
    
    var previewWindowSizing: PreviewWindowSizing {
        self.document.previewWindowSizingObserver
    }

    /// Shows menu wrapper view while node animation takes place
    var showMenu: Bool {
        graphUI.insertNodeMenuState.menuAnimatingToNode ||
        graphUI.insertNodeMenuState.show
    }

    var nodeAndMenu: some View {
        ZStack {
            contentView // the graph
            
            if showMenu {
                InsertNodeMenuWrapper(document: document,
                                      graphUI: graphUI,
                                      menuHeight: $menuHeight,
                                      screenSize: $screenSize) // node menu + other animating views
            }
        }
    }

    var body: some View {
        ZStack {
            // Must respect keyboard safe-area
            ProjectWindowSizeReader(previewWindowSizing: previewWindowSizing,
                                    previewWindowSize: document.previewWindowSize,
                                    isFullScreen: graphUI.isFullScreenMode,
                                    showFullScreenAnimateCompleted: $showFullScreenAnimateCompleted,
                                    showFullScreenObserver: showFullScreen,
                                    menuHeight: $menuHeight,
                                    screenSize: $screenSize,
                                    menuAnimatingToNode: graphUI.insertNodeMenuState.menuAnimatingToNode)

            // Must IGNORE keyboard safe-area
            nodeAndMenu
#if !targetEnvironment(macCatalyst)
                .ignoresSafeArea(edges: showFullScreen.isTrue ? [.all] : [.bottom])
                .ignoresSafeArea([.keyboard])
#endif
        }
       .environment(\.viewframe, graphUI.frame)
       .environment(\.isSelectionBoxInUse, graphUI.selection.isSelecting)
    }

    @ViewBuilder
    var contentView: some View {
        ZStack {
            
            // ALWAYS show full-screen preview on iPhone.
            // Also, if in full-screen preview mode on Catalyst or iPad, place the fullscreen preview on top.
            if showFullScreen.isTrue || GraphUIState.isPhoneDevice {
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
            if !GraphUIState.isPhoneDevice {
                // Check if we're on iPhone, otherwise the project view will start to render on
                // phone before showFullScreen is set
                ProjectNavigationView(document: document,
                                      insertNodeMenuHiddenNodeId: graphUI.insertNodeMenuState.hiddenNodeId,
                                      routerNamespace: routerNamespace)
                .zIndex(showFullScreen.isTrue ? -99 : 0)
                .overlay {
                    VStack {
                        if graphUI.groupNodeFocused?.component != nil {
                            ComponentNavBarView(graph: document.visibleGraph,
                                                store: store)
                        }
                        
                        HStack(spacing: .zero) {
                            Spacer()
                            // Floating preview kept outside NavigationSplitView for animation purposes
                            if !showFullScreen.isTrue {
                                FloatingWindowView(
                                    document: document,
                                    deviceScreenSize: graphUI.frame.size,
                                    showPreviewWindow: showPreviewWindow,
                                    namespace: graphNamespace)
                            }
                        }
                        
                        Spacer()
                    }
                }
//                // Layer Inspector Flyout must sit above preview window
                .overlay {
                    flyout
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
                                graph: document.graph) }
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
            LLMPromptModalView(actionsAsDisplay: document.llmRecording.promptState.actionsAsDisplayString)
        })
        .stitchSheet(isPresented: document.llmRecording.jsonEntryState.showModal,
                     titleLabel: "LLM JSON Entry",
                     hideAction: document.closedLLMActionsJSONEntryModal,
                     sheetBody: {
            LLMActionsJSONEntryModalView()
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
        OpenFlyoutView(graph: document.visibleGraph)
    }
}

// struct ContentView_Previews: PreviewProvider {
//
//    @Namespace static var namespace
//
//    static var previews: some View {
//        ContentView(metadata: .fakeProjectMetadata,
//                    graphSchema: .init(),
//                    graphUI: .init(),
//                    decodingWarning: nil,
//                    alertState: .init(),
//                    routerNamespace: namespace,
//                    syncStatus: .synced,
//                    exportableProject: nil,
//                    isShowingDrawer: true,
//                    broadcastChoices: .init())
//            //        .environment(\.graph)
//            .environmentObject(GraphUIState())
//            .environmentObject(VisibleNodesViewModel())
//            .environmentObject(PrototypePreviewViewModel())
//
//        //        let project = ProjectState(name: "test")
//        //
//        //        ContentView(nodePositionObserverMap: .init(),
//        //                    alertState: ProjectAlertState(),
//        //                    routerNamespace: namespace,
//        //                    syncStatus: .offline,
//        //                    exportableProject: nil,
//        //                    isShowingDrawer: false)
//        //            .previewDevice(PreviewDevice(rawValue: "iPad Pro (11-inch) (3rd generation)"))
//        //
//        //        ContentView(state: project,
//        //                    nodePositionObserverMap: .init(),
//        //                    alertState: ProjectAlertState(),
//        //                    routerNamespace: namespace,
//        //                    syncStatus: .synced,
//        //                    exportableProject: nil,
//        //                    isShowingDrawer: false)
//        //            .previewDevice(PreviewDevice(rawValue: "iPhone 13"))
//    }
// }
