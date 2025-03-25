//
//  CatalystNavigationBarHelperViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/11/24.
//

import SwiftUI
import StitchSchemaKit

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
    @Bindable var graphUI: GraphUIState
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
            .onChange(of: self.graphUI.reduxFocusedField == .projectTitle, initial: true) { oldValue, newValue in
                // log("CatalystProjectTitleModalView: .onChange(of: self.graphUI.reduxFocusedField): oldValue: \(oldValue)")
                // log("CatalystProjectTitleModalView: .onChange(of: self.graphUI.reduxFocusedField): newValue: \(newValue)")
                if !newValue {
                    // log("CatalystProjectTitleModalView: .onChange(of: self.graphUI.reduxFocusedField): will set focus false")
                    self.focus = false
                } else {
                    // log("CatalystProjectTitleModalView: .onChange(of: self.graphUI.reduxFocusedField): will set focus true")
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
    static let NEW_PROJECT_SF_SYMBOL_NAME = "doc.badge.plus" // SKIP

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

// TODO: update iPad graph view as well
struct CatalystTopBarGraphButtons: View {

    let document: StitchDocumentViewModel
    let graph: GraphState
    let hasActiveGroupFocused: Bool
    let isFullscreen: Bool // = false
    let isPreviewWindowShown: Bool // = true
    
    let llmRecordingModeEnabled: Bool
    let llmRecordingModeActive: Bool

    var body: some View {

        // `HStack` doesn't matter? These are all placed in a `ToolbarItemGroup` ...
        HStack {
            
// #if DEBUG || DEV_DEBUG || STITCH_AI
            
            CatalystNavBarButton(llmRecordingModeActive ? LLM_STOP_RECORDING_SF_SYMBOL : LLM_START_RECORDING_SF_SYMBOL) {
                dispatch(LLMRecordingToggled())
            }
            .opacity(llmRecordingModeEnabled ? 1 : 0)
// #endif
            
            CatalystNavBarButton(.GO_UP_ONE_TRAVERSAL_LEVEL_SF_SYMBOL_NAME) {
                dispatch(GoUpOneTraversalLevel())
            }
            // Use .opacity so that spacing doesn't change
            .opacity(hasActiveGroupFocused ? 1 : 0)

            CatalystNavBarButton(.ADD_NODE_SF_SYMBOL_NAME) {
                dispatch(ToggleInsertNodeMenu())
            }
            
            // TODO: should be a toast only shows up when no nodes are on-screen?
            CatalystNavBarButton(.FIND_NODE_ON_GRAPH) {
                graph.findSomeCanvasItemOnGraph(document: document)
            }

            // TODO: implement
            //            CatalystNavBarButton(.NEW_PROJECT_SF_SYMBOL_NAME) {
            //                //                dispatch(ProjectCreated())
            //                log("CatalystTopBarGraphButtons: to be implemented")
            //            }

//            CatalystNavBarButton(.TOGGLE_PREVIEW_WINDOW_SF_SYMBOL_NAME,
//                                 rotationZ: isPreviewWindowShown ? 0 : 180) {
            
            if !document.isDebugMode {
                CatalystNavBarButton(isPreviewWindowShown ? .HIDE_PREVIEW_WINDOW_SF_SYMBOL_NAME : .SHOW_PREVIEW_WINDOW_SF_SYMBOL_NAME) {
                    dispatch(TogglePreviewWindow())
                }
                
                CatalystNavBarButton(.RESTART_PROTOTYPE_SF_SYMBOL_NAME) {
                    dispatch(PrototypeRestartedAction())
                }
                
                CatalystNavBarButton(isFullscreen ? .SHRINK_FROM_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME : .EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME) {
                    dispatch(ToggleFullScreenEvent())
                }
            }
            

            CatalystNavBarButton(.SETTINGS_SF_SYMBOL_NAME) {
                PROJECT_SETTINGS_ACTION()
            }

            // TODO: implement
            //            CatalystNavBarButton(.SHARE_ICON_SF_SYMBOL_NAME) {
            //                // dispatch(ProjectShareButtonPressed(metadata: metadata))
            //                log("CatalystTopBarGraphButtons: to be implemented")
            //            }
            
            CatalystNavBarButton(action: {
                dispatch(LayerInspectorToggled())
            }, iconName: .sfSymbol("sidebar.right"))
        }
    }
}

struct LayerInspectorToggled: StitchDocumentEvent {
    func handle(state: StitchDocumentViewModel) {
        
        withAnimation {
            state.showsLayerInspector.toggle()
        }
        
        let graph = state.visibleGraph
        
        // reset selected inspector-row when inspector panel toggled
        graph.propertySidebar.selectedProperty = nil
        
        graph.closeFlyout()
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
    }
}

// TODO: 'toggle preview window' icon needs to change between hide vs show
// Hacky view to get hover effect on Catalyst topbar buttons
struct CatalystNavBarButton: View, Identifiable {

    // let systemName: String  for `Image(systemName:)`
    var image: Image
    let action: () -> Void
    var rotationZ: CGFloat = 0 // some icons stay the same but just get rotated

    var id: String

    var body: some View {
        Menu {
            // 'Empty menu' so that nothing happens when we tap the Menu's label
            EmptyView()
        } label: {
            Button(action: {}) {
                // TODO: any .resizable(), .fixedSize() etc. needed?
                image
            }
        }
        // rotation3DEffect must be applied here
        .rotation3DEffect(Angle(degrees: rotationZ),
                          axis: (x: 0, y: 0, z: rotationZ))

        // Hides the little arrow on Catalyst
        .menuIndicator(.hidden)

        // SwiftUI Menu's `primaryAction` enables label taps but also changes the button's appearance, losing the hover-highlight effect etc.;
        // so we use UIKitOnTapModifier for proper callback.
        .modifier(UIKitOnTapModifier(onTapCallback: action))

        // TODO: find ideal button size?
        // Note: *must* provide explicit frame
        .frame(width: 30, height: 30)
    }
}

extension CatalystNavBarButton {

    init(_ systemName: String,
         rotationZ: CGFloat = 0,
         _ action: @escaping () -> Void) {
        self.image = Image(systemName: systemName)
        self.action = action
        self.id = systemName
        self.rotationZ = rotationZ
    }

    init(action: @escaping () -> Void,
         iconName: IconName,
         rotationZ: CGFloat = 0) {
        self.image = iconName.image
        self.action = action
        self.id = iconName.name
        self.rotationZ = rotationZ
    }
}
