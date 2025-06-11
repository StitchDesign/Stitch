//
//  CatalystNavigationBarHelperViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/11/24.
//

import SwiftUI
import StitchSchemaKit
import TipKit

struct CatalystProjectTitleModalOpened: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        // log("CatalystProjectTitleModalOpened")
        withAnimation {
            state.showCatalystProjectTitleModal = true
        }
        state.reduxFieldFocused(focusedField: .projectTitle)
    }
}

struct CatalystProjectTitleModalClosed: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        // log("CatalystProjectTitleModalClosed")
        withAnimation {
            state.showCatalystProjectTitleModal = false
        }
        state.reduxFieldDefocused(focusedField: .projectTitle)
    }
}

struct CatalystProjectTitleModalView: View {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @FocusState var focus: Bool
    
    var body: some View {
        TextField("", text: $graph.name)
            .focused(self.$focus)
            .autocorrectionDisabled()
            .modifier(SelectAllTextViewModifier())
            .modifier(NavigationTitleFontViewModifier())
            .onAppear {
                // log("CatalystProjectTitleModalView: onAppear")
                self.focus = true
            }
            .onChange(of: self.document.reduxFocusedField == .projectTitle, initial: true) { oldValue, newValue in
                // log("CatalystProjectTitleModalView: .onChange(of: self.document.reduxFocusedField): oldValue: \(oldValue)")
                // log("CatalystProjectTitleModalView: .onChange(of: self.document.reduxFocusedField): newValue: \(newValue)")
                if !newValue {
                    // log("CatalystProjectTitleModalView: .onChange(of: self.document.reduxFocusedField): will set focus false")
                    self.focus = false
                } else {
                    // log("CatalystProjectTitleModalView: .onChange(of: self.document.reduxFocusedField): will set focus true")
                    self.focus = true
                }
            }
        // Do not use `initial: true`
            .onChange(of: self.focus) { oldValue, newValue in
                // log("CatalystProjectTitleModalView: .onChange(of: self.focus): oldValue: \(oldValue)")
                // log("CatalystProjectTitleModalView: .onChange(of: self.focus): newValue: \(newValue)")
                if newValue {
                    dispatch(ReduxFieldFocused(focusedField: .projectTitle))
                } else {
                    // log("CatalystNavBarTitleEditField: defocused, so will commit")
                    graph.name = graph.name.validateProjectTitle()
                    dispatch(ReduxFieldDefocused(focusedField: .projectTitle))
                    dispatch(CatalystProjectTitleModalClosed())
                    // Commit project name to disk
                    graph.encodeProjectInBackground()
                }
            }
    }
}

// Imitates the .navigationTitle($someBinding) edit experience on iPad
struct CatalystNavBarProjectTitleDisplayView: View {
    @Bindable var graph: GraphState
    
    var body: some View {
        Text(graph.name)
            .modifier(NavigationTitleFontViewModifier())
            .padding(6)
            .frame(width: 260, height: 16, alignment: .leading)
            .onTapGesture {
                dispatch(CatalystProjectTitleModalOpened())
            }
    }
}

struct NavigationTitleFontViewModifier: ViewModifier {

    // imitates .navigationTitle font weight
    func body(content: Content) -> some View {
        content
            .font(.title3)
            .bold()
    }
}

/// When we first begin editing a TextField, auto-select all text
struct SelectAllTextViewModifier: ViewModifier {

    // `content` should be a `TextField`
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(
                        for: UITextField.textDidBeginEditingNotification)) { _ in
                DispatchQueue.main.async {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil
                    )
                }
            }
    }
}

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
    @Bindable var document: StitchDocumentViewModel
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
            
            CatalystNavBarButton(.ADD_NODE_SF_SYMBOL_NAME,
                                 toolTip: "Add Node") {
                dispatch(ToggleInsertNodeMenu())
            }
            
            // TODO: only show when no nodes are on-screen?
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

// Hacky view to get hover effect on Catalyst topbar buttons and to enforce gray tint
struct CatalystNavBarButton: View {

    init(_ systemName: String,
         toolTip: String,
         rotationZ: CGFloat = 0,
         _ action: @escaping () -> Void) {
        self.systemName = systemName
        self.toolTip = toolTip
        self.action = action
        self.rotationZ = rotationZ
    }
    
    let systemName: String
    let toolTip: String
        
    let action: () -> Void
    
    // Only the graph-reset icon rotates?
    var rotationZ: CGFloat = 0
        
    var body: some View {
        
        // HACK to get tooltips working on Mac Catalyst; can't use SwiftUI `.help`
        ZStack {
            CatalystToolbarButton(
                systemImageName: systemName, // "gearshape",
                tooltipText: toolTip //"Open Settings"
            ) {
                // log("my action here")
            }
            .fixedSize()
            
            Menu {
                // 'Empty menu' so that nothing happens when we tap the Menu's label
                EmptyView()
            } label: {
                Button(action: {}) {
                    EmptyView()
                }
            }
            // rotation3DEffect must be applied here
            .rotation3DEffect(Angle(degrees: rotationZ),
                              axis: (x: 0, y: 0, z: rotationZ))

            .modifier(CatalystTopBarButtonStyle())
            
            .simultaneousGesture(TapGesture().onEnded({ _ in
                action()
            }))
        }
        
//        Menu {
//            // 'Empty menu' so that nothing happens when we tap the Menu's label
//            EmptyView()
//        } label: {
//            Button(action: {}) {
//                // TODO: any .resizable(), .fixedSize() etc. needed?
//                image
//            }
//        }
//        // rotation3DEffect must be applied here
//        .rotation3DEffect(Angle(degrees: rotationZ),
//                          axis: (x: 0, y: 0, z: rotationZ))
//
//        .modifier(CatalystTopBarButtonStyle())
//        .simultaneousGesture(TapGesture().onEnded({ _ in
//            action()
//        }))

        // SwiftUI Menu's `primaryAction` enables label taps but also changes the button's appaearance, losing the hover-highlight effect etc.;
        // so we use UIKitOnTapModifier for proper callback.
//        .modifier(UIKitOnTapModifier(onTapCallback: action))
    }
}

struct CatalystTopBarButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
        // Hides the little arrow on Catalyst
        .menuIndicator(.hidden)
        
        // TODO: find ideal button size?
        // Note: *must* provide explicit frame
        .frame(width: 30, height: 30)
    }
}
