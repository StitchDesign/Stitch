//
//  CatalystNavigationBarHelperViews.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/11/24.
//

import SwiftUI
import StitchSchemaKit

// Imitates the .navigationTitle($someBinding) edit experience on iPad
struct CatalystNavBarTitleEditField: View {
    @Bindable var graph: GraphState

    @FocusState var focus: Bool
    
    var body: some View {
        TextField("", text: $graph.projectName)
            .focused(self.$focus)
            .autocorrectionDisabled()
            .modifier(SelectAllTextViewModifier())
            .modifier(NavigationTitleFontViewModifier())
            .padding(6)
        
            // worked well with Sonoma 14.3 and earlier
            // .frame(minWidth: self.focus ? 260 : 30, maxWidth: 400)
            
            // fix for issue with Sonoma 14.4
            // .frame(minWidth: 260, maxWidth: 400)
        
            // Padding alone does not prevent text field from sliding to the left and covering the back-button etc. ...
            // .padding(.trailing, 64)
        
            // ... setting an explicit width seems necessary to prevent the text field from covering the back-button during a long title edit
            .width(260)
        
            .overlay { fieldHighlight }
            .onChange(of: self.focus) { oldValue, newValue in
                log("CatalystNavBarTitleEditField: .onChange(of: self.focus): oldValue: \(oldValue)")
                log("CatalystNavBarTitleEditField: .onChange(of: self.focus): newValue: \(newValue)")
                withAnimation(.easeOut(duration: 0.2)) {
                    self.focus = newValue
                }

                if newValue {
                    dispatch(ReduxFieldFocused(focusedField: .projectTitle))
                } else {
                    // log("CatalystNavBarTitleEditField: defocused, so will commit")
                    graph.projectName = graph.projectName.validateProjectTitle()
                    // Commit project name to disk
                    self.graph.encodeProjectInBackground()
                }
            }
    }
    
    var fieldHighlight: some View {
        RoundedRectangle(cornerRadius: 8)
            .stroke(Color.accentColor,
                    lineWidth: self.focus ? 2 : 0)
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

    let graphUI: GraphUIState
    let hasActiveGroupFocused: Bool
    let isFullscreen: Bool // = false
    let isPreviewWindowShown: Bool // = true
    
    let llmRecordingModeEnabled: Bool
    let llmRecordingModeActive: Bool

    var body: some View {

        // `HStack` doesn't matter? These are all placed in a `ToolbarItemGroup` ...
        HStack {
            
            CatalystNavBarButton(llmRecordingModeActive ? "stop.fill" : "play.fill") {
                dispatch(LLMRecordingToggled())
            }
            .opacity(llmRecordingModeEnabled ? 1 : 0)
            
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
                dispatch(FindSomeCanvasItemOnGraph())
            }

            // TODO: implement
            //            CatalystNavBarButton(.NEW_PROJECT_SF_SYMBOL_NAME) {
            //                //                dispatch(ProjectCreated())
            //                log("CatalystTopBarGraphButtons: to be implemented")
            //            }

            CatalystNavBarButton(.TOGGLE_PREVIEW_WINDOW_SF_SYMBOL_NAME,
                                 rotationZ: isPreviewWindowShown ? 0 : 180) {
                dispatch(TogglePreviewWindow())
            }

            CatalystNavBarButton(.RESTART_PROTOTYPE_SF_SYMBOL_NAME) {
                dispatch(PrototypeRestartedAction())
            }

            CatalystNavBarButton(isFullscreen ? .SHRINK_FROM_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME : .EXPAND_TO_FULL_SCREEN_PREVIEW_WINDOW_SF_SYMBOL_NAME) {
                dispatch(ToggleFullScreenEvent())
            }

            CatalystNavBarButton(.SETTINGS_SF_SYMBOL_NAME) {
                PROJECT_SETTINGS_ACTION()
            }

            // TODO: implement
            //            CatalystNavBarButton(.SHARE_ICON_SF_SYMBOL_NAME) {
            //                // dispatch(ProjectShareButtonPressed(metadata: metadata))
            //                log("CatalystTopBarGraphButtons: to be implemented")
            //            }
            
            if FeatureFlags.USE_LAYER_INSPECTOR {
                CatalystNavBarButton(action: {
                    self.graphUI.showsLayerInspector.toggle()
                }, iconName: .sfSymbol("sidebar.right"))
            }
        }
    }
}

struct GoUpOneTraversalLevel: GraphEvent {

    func handle(state: GraphState) {

        log("GoUpOneTraversalLevel called")
        
        guard state.graphUI.groupNodeFocused.isDefined else {
            // If there's no current group node, do nothing
            log("GoUpOneTraversalLevel: already at top level")
            return
        }
        
        state.graphUI.groupNodeBreadcrumbs = state.graphUI.groupNodeBreadcrumbs.dropLast()

        // Set new active parent
        state.graphUI.groupNodeFocused = state.graphUI.groupNodeBreadcrumbs.last?.asGroupNodeId

        // Reset any active selections
        state.resetAlertAndSelectionState()

        // Zoom-out animate to parent
        state.graphUI.groupTraversedToChild = false
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
