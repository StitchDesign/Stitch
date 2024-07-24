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
    
    var previewWindowSizing: PreviewWindowSizing {
        self.graph.previewWindowSizingObserver
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
                                      routerNamespace: routerNamespace)
                .zIndex(showFullScreen.isTrue ? -99 : 0)
                .overlay {
                    // Floating preview kept outside NavigationSplitView for animation purposes
                    if !showFullScreen.isTrue {
                        FloatingWindowView(
                            graph: graph,
                            deviceScreenSize: graphUI.frame.size,
                            showPreviewWindow: showPreviewWindow,
                            namespace: graphNamespace)
                    }
                }
                // Layer Inspector Flyout must sit above preview window
                .overlay {
                    flyout
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
            DispatchQueue.main.async {
                self.showFullScreenAnimateCompleted = true
            }
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
    
    @ViewBuilder
    var flyout: some View {
        
        if let flyoutState = graph.graphUI.propertySidebar.flyoutState,
           let node = graph.getNodeViewModel(flyoutState.input.nodeId),
           let layerNode = node.layerNode,
           let entry = graph.graphUI.propertySidebar.propertyRowOrigins.get(flyoutState.flyoutInput) {
            
            let flyoutSize = flyoutState.flyoutSize
            let inputData = layerNode[keyPath: flyoutState.flyoutInput.layerNodeKeyPath]
            
            // If pseudo-modal-background placed here,
            // then we disable scroll
            #if DEV_DEBUG || DEBUG
            let pseudoPopoverBackgroundOpacity = 0.1
            #else
            let pseudoPopoverBackgroundOpacity = 0.001
            #endif
            
            Color.blue.opacity(pseudoPopoverBackgroundOpacity)
            // SwiftUI native .popover disables scroll; probably best solution here.
            // .offset(x: -LayerInspectorView.LAYER_INSPECTOR_WIDTH)
                .onTapGesture {
                    dispatch(FlyoutClosed())
                }
            
            HStack {
                Spacer()
                Group {
                    if flyoutState.flyoutInput == .padding {
                        PaddingFlyoutView(graph: graph,
                                          rowViewModel: inputData.inspectorRowViewModel,
                                          layer: layerNode.layer,
                                          hasIncomingEdge: inputData.rowObserver.containsUpstreamConnection)
                    } else if flyoutState.flyoutInput == SHADOW_FLYOUT_LAYER_INPUT_PROXY {
                        ShadowFlyoutView(node: node, layerNode: layerNode, graph: graph)
                    }
                }
                .offset(
                    x: -LayerInspectorView.LAYER_INSPECTOR_WIDTH // move left
                    - 8, // "padding"
                    
                    y:  -(graph.graphUI.frame.midY - flyoutSize.height/2) // move up to top of graph
                    + entry.y // move down to row's y height
                    + INSPECTOR_LIST_TOP_PADDING // move up per inspector's list padding
                )
            }
        }
    } // var flyout: some View { ...
    
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
