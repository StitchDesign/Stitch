//
//  GraphBase.swift
//  prototype
//
//  Created by Christian J Clampitt on 1/26/22.
//

import SwiftUI
import StitchSchemaKit

// Grid lines, cursor, selection box, patch and layer nodes
struct GraphBaseView: View {
    
    static let coordinateNamespace = "GRAPHBASEVIEW_NAMESPACE"
    
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    
    @Environment(\.safeAreaInsets) private var safeAreaInsets: SafeAreaInsets
    
    @State private var spaceHeld = false

    @Bindable var document: StitchDocumentViewModel
    @Bindable var graphUI: GraphUIState
    
    @MainActor
    var graph: GraphState {
        self.document.visibleGraph
    }

    var body: some View {
        // Our screen device measurements ignore the safe area,
        // so our touch-responsive interfaces must ignore them to.

        nodesAndCursor
            .onAppear {
                #if targetEnvironment(macCatalyst)
                if self.spaceHeld || document.keypressState.isSpacePressed {
                    NSCursor.openHand.push()
                }
                #endif
                dispatch(ColorSchemeReceived(colorScheme: colorScheme))
                dispatch(SafeAreaInsetsReceived(insets: safeAreaInsets))
            }
            .onChange(of: colorScheme) { _, color in
                //                log("GraphBaseView: onChange of ColorScheme")
                dispatch(ColorSchemeReceived(colorScheme: color))
            }
            .onChange(of: safeAreaInsets) { _, insets in
                //                log("GraphBaseView: onChange of safeAreaInsets")
                dispatch(SafeAreaInsetsReceived(insets: insets))
            }

        #if targetEnvironment(macCatalyst)
            .modifier(GraphHoverViewModifier(spaceHeld: self.$spaceHeld,
                                             document: document))
        #endif
    }

    @MainActor
    var selectionState: GraphUISelectionState {
        graphUI.selection
    }

    @ViewBuilder
    @MainActor
    var nodesView: some View {
        NodesView(document: document,
                  graph: graph,
                  groupTraversedToChild: graphUI.groupTraversedToChild)
        .overlay {
            // Show debug mode tip view
            if document.isDebugMode {
                VStack {
                    HStack {
                        DebugModePopover()
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            if document.llmRecording.modal == .approveAndSubmit {
                VStack {
                    HStack {
                        LLMApprovalModalView(prompt: document.llmRecording.promptState.prompt)
                        Spacer()
                    }
                    Spacer()
                }
            }
            
            // Better to show modal here, so user can move around etc.
            if document.llmRecording.modal == .editBeforeSubmit {
                VStack {
                    HStack {
                        EditBeforeSubmitModalView(
                            document: document,
                            graph: graph)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder
    @MainActor
    var nodesAndCursor: some View {
        ZStack {
            #if DEV_DEBUG
            // Use `ZStack { ...` instead of `ZStack(alignment: .top) { ...`
            // to get in exact screen center.
            Circle().fill(.cyan.opacity(0.5))
                .frame(width: 60, height: 60)
            #endif

            nodesView

            // To cover top safe area that we don't ignore on iPad and that is gesture-inaccessbile
            Stitch.APP_BACKGROUND_COLOR
                .edgesIgnoringSafeArea(.all).zIndex(-10)
                
            // IMPORTANT: applying .inspector outside of this ZStack causes displacement of graph contents when graph zoom != 1
            Circle().fill(Stitch.APP_BACKGROUND_COLOR.opacity(0.001))
                .frame(width: 1, height: 1)
                .inspector(isPresented: $graphUI.showsLayerInspector) {
                    
                    LayerInspectorView(graph: graph)
                    
                    // TODO: setting an inspector width DOES move over the graph view content
                        .inspectorColumnWidth(LayerInspectorView.LAYER_INSPECTOR_WIDTH)
                }
        } // ZStack
        .coordinateSpace(name: Self.coordinateNamespace)
        .background {
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .local), initial: true) { oldValue, newValue in
                        // log("SIZE READING: GraphBaseView: local frame: newValue: \(newValue)")
                        dispatch(SetDeviceScreenSize(frame: newValue))
                    }
                    .onChange(of: geometry.frame(in: .global), initial: true) { oldValue, newValue in
                        // log("SIZE READING: GraphBaseView: global frame: newValue: \(newValue)")
                        dispatch(SetGraphYPosition(graphYPosition: newValue.origin.y))
                        dispatch(SetSidebarWidth(frame: newValue))
                    }
            } // GeometryReader
        } // .background
    }
}

struct GraphHoverViewModifier: ViewModifier {
    @Binding var spaceHeld: Bool
    @Bindable var document: StitchDocumentViewModel
    
    func body(content: Content) -> some View {
        content
#if targetEnvironment(macCatalyst)
            .onHover(perform: { hovering in
                
                // log("GraphBaseView: onHover: hovering: \(hovering)")
                // log("GraphBaseView: onHover: graphUI.keypressState.isSpacePressed: \(graphUI.keypressState.isSpacePressed)")
                // log("GraphBaseView: onHover: self.spaceHeld: \(self.spaceHeld)")
                
                if hovering, self.spaceHeld {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
            })
        
            .onChange(of: document.keypressState.isSpacePressed, initial: true) { _, newValue in
                // log("GraphBaseView: onChange: keypressState.isSpacePressed: oldValue: \(oldValue)")
                // log("GraphBaseView: onChange: keypressState.isSpacePressed: newValue: \(newValue)")
                
                if newValue {
                    NSCursor.openHand.push()
                } else {
                    NSCursor.pop()
                }
                
                if self.spaceHeld != newValue {
                    self.spaceHeld = newValue
                }
            }
#endif
    }
}
