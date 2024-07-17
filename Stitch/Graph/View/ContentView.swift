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

struct ContentView: View {
    @State private var menuHeight: CGFloat = INSERT_NODE_MENU_MAX_HEIGHT
    
    // Controlled by a GeometryReader that respects keyboard safe-area,
    // so that menuOrigin respects actual height of screen
    // (which is smaller when full-screen keyboard is on-screen).
    @State private var screenSize: CGSize = .zero
    
    @Namespace private var graphNamespace
    @StateObject private var showFullScreen = AnimatableBool(false)
    @StateObject private var previewWindowSizing = PreviewWindowSizing()
    @State private var showFullScreenAnimateCompleted = true
    
    // Controls the animation of newly created node from the insert node menu
    @State private var previewingNodeChoice: InsertNodeMenuOption?

    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState

    let alertState: ProjectAlertState
    let routerNamespace: Namespace.ID

    var showPreviewWindow: Bool {
        graphUI.showPreviewWindow
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
                InsertNodeMenuWrapper(graph: graph,
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
                                    previewWindowSize: graph.previewWindowSize,
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
                        graph.previewWindowBackgroundColor.overlay {
                            Color.black.opacity(0.2)
                        }
                    }
            } // if showFullScreen.isTrue
            
            // NEVER show graph-view on iPhone
            if !GraphUIState.isPhoneDevice {
                // Check if we're on iPhone, otherwise the project view will start to render on
                // phone before showFullScreen is set
                ProjectNavigationView(graph: graph,
                                      insertNodeMenuHiddenNodeId: graphUI.insertNodeMenuState.hiddenNodeId,
                                      routerNamespace: routerNamespace,
                                      previewWindowSizing: previewWindowSizing)
                .zIndex(showFullScreen.isTrue ? -99 : 0)
                .overlay {
                    // Floating preview kept outside NavigationSplitView for animation purposes
                    if !showFullScreen.isTrue {
                        FloatingWindowView(
                            graph: graph,
                            deviceScreenSize: graphUI.frame.size,
                            showPreviewWindow: showPreviewWindow,
                            namespace: graphNamespace,
                            previewWindowSizing: previewWindowSizing)
                    }
                }
                // Layer Inspector Flyout must sit above preview window
                .overlay {
        
//                    if let flyoutState = graph.graphUI.propertySidebar.flyoutState,
//                       let rowObserver = graph.getInputObserver(coordinate: flyoutState.input),
//                       let entry = graph.graphUI.propertySidebar.propertyRowOrigins.get(flyoutState.flyoutInput) {
//                        
//                        let flyoutSize = flyoutState.flyoutSize
                         
                    if let entry = graph.graphUI.propertySidebar.propertyRowOrigins.first {
                    
                        // If pseudo-modal-background placed here,
                        // then we disable scroll
                        Color.blue.opacity(0.5)
//                        Color.blue.opacity(0.001)
                        
                        // SwiftUI native .popover disables scroll; probably best solution here.
                            .offset(x: -LayerInspectorView.LAYER_INSPECTOR_WIDTH)
                            .onTapGesture {
                                dispatch(FlyoutClosed())
                            }
                        
                        let deviceScreen = graph.graphUI.frame
                        let flyoutLength = 200.0
                        
                        HStack {
                            Spacer()
                            Rectangle()
                                .fill(.red.opacity(0.75))
                                .frame(width: flyoutLength, height: flyoutLength)
                                .border(.yellow, width: 10)
                                .overlay {
                                    Circle().fill(.green).frame(width: 60)
                                }
                                .offset(
                                    x: -LayerInspectorView.LAYER_INSPECTOR_WIDTH // move left
                                    - 8, // padding
                                    
                                    y:  -(deviceScreen.midY - flyoutLength/2) // move up to top of graph
                                    + entry.value.y // move down to row's y height
                                    + INSPECTOR_LIST_TOP_PADDING // move up per inspector's lisst padding
                                )
                        }
                        
                        
                        /*
                          TODO: better handling of left-sidebar; either avoid its displacement effect or properly read the actual width of the left sidebar
                         
                         Ideally, the flyout is not displaced by left sidebar.
                         
                         Preview Window is not displaced by left sidebar because we use an HStack + Spacer()
                         
                         However, a .position'd view always seems to be displaced when left sidebar is open, even when the position is based on the origin in a coordinate space that changes.
                         
                         Interestingly:
                         1. even a StitchRootView coordinate space is displayed by left sidebar, and
                         2. even when a view uses a hardcoded x-value, the view gets displaced.
                         
                         For now, we just close the flyout when the sidebar is opened.
                         */
//                        PaddingFlyoutView(graph: graph,
//                                          rowObserver: rowObserver)
                        
//                        .position(
//                            // 8 = padding from edge of inspector
//                            // TODO: use left edge of property sidebar
////                            x: entry.x - flyoutSize.width/2 - 8 - 36,
//                            
////                            x: entry.x - flyoutSize.width/2 - 8 - 36 - (graph.graphUI.leftSidebarIsOpen ? SIDEBAR_WIDTH : 0),
//                            
//                            x: entry.x - flyoutSize.width/2 - 36 - (graph.graphUI.leftSidebarIsOpen ? SIDEBAR_WIDTH : 0),
////
////                            x: entry.x - flyoutSize.width/2 - 8 - 36 - SIDEBAR_WIDTH,
//                            
//                            
//                            // TODO: use a coordinate space that ignores the property sidebar's negative top padding?
//                            y: entry.y + flyoutSize.height/2 + INSPECTOR_LIST_TOP_PADDING
//                        )
                        
//                        .transition(.opacity)
                    }
                }
                
                
                // Note: we want the floating preview window to 'ignore safe areas' (e.g. the keyboard rising up should not affect preview window's size or pposition):
                // we must apply the `.ignoresSafeArea` modifier to the ProjectNavigationView, rather than .overlay's contents
#if !targetEnvironment(macCatalyst)
                .ignoresSafeArea(edges: showFullScreen.isTrue ? [.all] : [.bottom])
                .ignoresSafeArea([.keyboard])
#endif
            }
        } // ZStack
        
        .stitchSheet(isPresented: alertState.showProjectSettings,
                     titleLabel: "Settings",
                     hideAction: HideProjectSettingsSheet()) {
            ProjectSettingsView(previewWindowSize: graph.previewWindowSize,
                                previewSizeDevice: graph.previewSizeDevice,
                                previewWindowBackgroundColor: graph.previewWindowBackgroundColor,
                                graph: graph) }
        .modifier(FileImportView(fileImportState: alertState.fileImportModalState))
        .modifier(AnimateCompletionHandler(percentage: showFullScreen.value) {
            // only set this state to true when we're animating into full screen mode
            showFullScreenAnimateCompleted = true
        })
        .stitchSheet(isPresented: graph.graphUI.llmRecording.promptState.showModal,
                     titleLabel: "LLM Recording",
                     hideAction: LLMRecordingPromptClosed(),
                     sheetBody: {
            LLMPromptModalView(actionsAsDisplay: graph.graphUI.llmRecording.promptState.actionsAsDisplayString)
        })
        .stitchSheet(isPresented: graph.graphUI.llmRecording.jsonEntryState.showModal,
                     titleLabel: "LLM JSON Entry",
                     hideAction: LLMActionsJSONEntryModalClosed(),
                     sheetBody: {
            LLMActionsJSONEntryModalView()
        })
    }

    private var fullScreenPreviewView: some View {
        FullScreenPreviewViewWrapper(
            graphState: graph, 
            previewWindowSizing: self.previewWindowSizing, 
            showFullScreenPreviewSheet: alertState.showFullScreenPreviewSheet,
            graphNamespace: graphNamespace,
            routerNamespace: routerNamespace,
            animationCompleted: showFullScreenAnimateCompleted)
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
