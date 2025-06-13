//
//  CatalystNavigationBarHelperViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/11/24.
//

import SwiftUI
import StitchSchemaKit
import TipKit


// Note: intended for Catalyst, but hopefully we move all our icons over to SF Symbol?
extension String {

    // Right side graph buttons, in Figma design order, left to right:
    static let GO_UP_ONE_TRAVERSAL_LEVEL_SF_SYMBOL_NAME = "arrow.turn.left.up"
    static let FIND_NODE_ON_GRAPH = "location.viewfinder"
    static let ADD_NODE_SF_SYMBOL_NAME = "plus.rectangle"
    static let NEW_PROJECT_SF_SYMBOL_NAME = "doc.badge.plus"
    static let OPEN_SAMPLE_PROJECTS_MODAL = "arrow.down.document"

    // Hide = arrow to the right,
    // Show = arrow to the left
    // Hide vs Show use same SFSymbol but just rotated
    static let TOGGLE_PREVIEW_WINDOW_SF_SYMBOL_NAME = "rectangle.portrait.and.arrow.right"
    
    // Note: `iphone` is gray and "Can Only Refer to iPhone" per SFSymbol docs?
//    static let SHOW_PREVIEW_WINDOW_SF_SYMBOL_NAME = "iphone"
//    static let HIDE_PREVIEW_WINDOW_SF_SYMBOL_NAME = "iphone.slash"
    static let SHOW_PREVIEW_WINDOW_SF_SYMBOL_NAME = "rectangle.portrait"
    static let HIDE_PREVIEW_WINDOW_SF_SYMBOL_NAME = "rectangle.portrait.slash"

    static let RESTART_PROTOTYPE_SF_SYMBOL_NAME = "arrow.clockwise"
    static let EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME = "arrow.up.left.and.arrow.down.right"

    static let SHRINK_FROM_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME =  "arrow.down.forward.and.arrow.up.backward"

    static let SHARE_ICON_SF_SYMBOL_NAME = "square.and.arrow.up"

    // NO, NOT USED ON CATALYST
    static let MISCELLANEOUS_OPTIONS_SF_SYMBOL_MAME = "ellipsis.circle"

    // on Graph, sits inside the misc options button
    // on Homescreen
    static let SETTINGS_SF_SYMBOL_NAME = "gear"

    // Unused; originally planned for center buttons
    static let FOCUS_MODE_SF_SYMBOL_NAME = "circle"
}

struct CatalystTopBarGraphButtons: View {
    @Bindable var document: StitchDocumentViewModel // Not needed?
    let isDebugMode: Bool
    let hasActiveGroupFocused: Bool
    let isFullscreen: Bool
    let isPreviewWindowShown: Bool
    
    var body: some View {
        Group {
            CatalystNavBarButton(.GO_UP_ONE_TRAVERSAL_LEVEL_SF_SYMBOL_NAME,
                                 toolTip: "Go up one traversal level") {
                dispatch(GoUpOneTraversalLevel())
            }
            .opacity(hasActiveGroupFocused ? 1 : 0)
            
            if FeatureFlags.SHOW_TRAINING_EXAMPLE_GENERATION_BUTTON {
                CatalystNavBarButton("Sparkles",
                                     toolTip: "Submit graph as AI training example") {
                    dispatch(ShowCreateTrainingDataFromExistingGraphModal())
                }
            }
            
            CatalystNavBarButtonWithMenu(
                systemName: .ADD_NODE_SF_SYMBOL_NAME,
                toolTip: "Add Nodes") {
                    StitchButton {
                        dispatch(ShowAINodePromptEntryModal())
                    } label: {
                        Text(String.CREATE_CUSTOM_NODE_WITH_AI)
                    }
                    StitchButton {
                        dispatch(ToggleInsertNodeMenu())
                    } label: {
                        Text("Add Nodes")
                    }
                }
                        
            // TODO: only show when no nodes are on-screen?
            // and so should be placed on the far left?
            CatalystNavBarButton(.FIND_NODE_ON_GRAPH,
                                 toolTip: "Find Node") {
                dispatch(FindSomeCanvasItemOnGraph())
            }
            
            if !isDebugMode {
                CatalystNavBarButton(isPreviewWindowShown ? .HIDE_PREVIEW_WINDOW_SF_SYMBOL_NAME : .SHOW_PREVIEW_WINDOW_SF_SYMBOL_NAME,
                                     toolTip: "Toggle Prototype Window") {
                    dispatch(TogglePreviewWindow())
                }
                
                CatalystNavBarButton(.RESTART_PROTOTYPE_SF_SYMBOL_NAME,
                                     toolTip: "Restart Prototype") {
                    dispatch(PrototypeRestartedAction())
                }
                
                CatalystNavBarButton(isFullscreen ? .SHRINK_FROM_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME : .EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME,
                                     toolTip: "Toggle Fullscreen") {
                    dispatch(ToggleFullScreenEvent())
                }
            }
            
            TopBarSharingButtonsView(document: document)
                .modifier(CatalystTopBarButtonStyle())
            
            TopBarFeedbackButtonsView(document: self.document)
                .modifier(CatalystTopBarButtonStyle())
            
            CatalystNavBarButton(.SETTINGS_SF_SYMBOL_NAME,
                                 toolTip: "Open Settings") {
                PROJECT_SETTINGS_ACTION()
            }
            
            CatalystNavBarButton("sidebar.right",
                                 toolTip: "Toggle Layer Inspector") {
                dispatch(LayerInspectorToggled())
            }
        }
    }
}

struct LayerInspectorToggled: StitchStoreEvent {
    func handle(store: StitchStore) -> ReframeResponse<NoState> {
        
        withAnimation {
            store.showsLayerInspector.toggle()
        }
        
        guard let graph = store.currentDocument?.visibleGraph else {
            return .noChange
        }
        
        // reset selected inspector-row when inspector panel toggled
        graph.propertySidebar.selectedProperty = nil
        
        graph.closeFlyout()
        
        return .noChange
    }
}

struct GoUpOneTraversalLevel: StitchDocumentEvent {

    func handle(state: StitchDocumentViewModel) {

        log("GoUpOneTraversalLevel called")
        
        guard state.groupNodeFocused.isDefined else {
            // If there's no current group node, do nothing
            log("GoUpOneTraversalLevel: already at top level")
            return
        }
        
        // Set new active parent
        state.groupNodeBreadcrumbs.removeLast()

        // Reset any active selections
        state.visibleGraph.resetAlertAndSelectionState(document: state)

        // Zoom-out animate to parent
        state.groupTraversedToChild = false
        
        // Updates graph data
        state.refreshGraphUpdaterId()
    }
}

