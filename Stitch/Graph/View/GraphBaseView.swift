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

    @Bindable var store: StitchStore
    @Bindable var document: StitchDocumentViewModel
    
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

    @ViewBuilder @MainActor
    var nodesView: some View {
        NodesView(document: document,
                  graph: graph,
                  groupTraversedToChild: document.groupTraversedToChild)
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

    @ViewBuilder @MainActor
    var nodesAndCursor: some View {
//        ZStack {
        ZStack(alignment: .center) {
            
            // To cover top safe area that we don't ignore on iPad and that is gesture-inaccessbile
//            Stitch.APP_BACKGROUND_COLOR
//                .edgesIgnoringSafeArea(.all)
                // .zIndex(-10)
            
            #if DEV_DEBUG
            // Use `ZStack { ...` instead of `ZStack(alignment: .top) { ...`
            // to get in exact screen center.
            Circle().fill(.cyan.opacity(0.5))
                .frame(width: 60, height: 60)
            #endif

            
            // lets us draw edge over it, but canvas items also go over
//            Circle().fill(Stitch.APP_BACKGROUND_COLOR.opacity(0.001))
//                .frame(width: 1, height: 1)
//                .inspector(isPresented: $store.showsLayerInspector) {
//                    
//                    LayerInspectorView(graph: graph,
//                                       document: document)
//                        .inspectorColumnWidth(LayerInspectorView.LAYER_INSPECTOR_WIDTH)
//                }
            
            nodesView
                          
            // IMPORTANT: applying .inspector outside of this ZStack causes displacement of graph contents when graph zoom != 1
            Circle().fill(Stitch.APP_BACKGROUND_COLOR.opacity(0.001))
                .frame(width: 1, height: 1)
                .inspector(isPresented: $store.showsLayerInspector) {
                    
                    LayerInspectorView(graph: graph,
                                       document: document)
                        .inspectorColumnWidth(LayerInspectorView.LAYER_INSPECTOR_WIDTH)
                }
            
            // Added: place "actively dragged edge" view here, so we can sit above the inspector
            // NEED TO SCALE AND OFFSET THE DRAGGED
            EdgeDrawingView(graph: graph,
                            edgeDrawingObserver: graph.edgeDrawingObserver)
            
        } // ZStack
        
        // TODO: MAY 12: ONLY ACTIVE WHEN WE
        // this fires everytime we have a change ?
        .overlayPreferenceValue(ViewFramePreferenceKey.self) { preferences in
            GeometryReader { proxy in
                if let draggedOutput = preferences[String.DRAGGED_OUTPUT].map({ proxy[$0] }),
                   let sizeInput = preferences[String.SIZE_INPUT].map({ proxy[$0] }) {
                    
                    let intersects = draggedOutput.intersects(sizeInput)
                    
                    logInView("preference: draggedOutput.mid.x: \(draggedOutput.mid.x)")
                    logInView("preference: draggedOutput.mid.y: \(draggedOutput.mid.y)")
                    logInView("preference: draggedOutput.size: \(draggedOutput.size)")
                    
                    logInView("preference: sizeInput.mid.x: \(sizeInput.mid.x)")
                    logInView("preference: sizeInput.mid.y: \(sizeInput.mid.y)")
                    logInView("preference: sizeInput.size: \(sizeInput.size)")
                    
                    logInView("preference: Intersection: \(intersects)")
                    
                    CurveLine(from: draggedOutput.mid,
                              to: sizeInput.mid)
                    .stroke(.green,
                            style: StrokeStyle(lineWidth: LINE_EDGE_WIDTH,
                                               lineCap: .round,
                                               lineJoin: .round))
//
//                    EdgeDrawingView(graph: graph,
//                                    edgeDrawingObserver: graph.edgeDrawingObserver)
//                    
                } else {
                    EmptyView()
                }
//
//                Color.clear
//                    .onAppear {
//                        print("on appear: Intersection: \(intersects)")
//                    }
            }
        }
        
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

extension String {
    static let DRAGGED_OUTPUT = "DRAGGED_OUTPUT"
    static let SIZE_INPUT = "SIZE_INPUT"
}

struct ViewFramePreferenceKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func trackFrame(id: String) -> some View {
        self.anchorPreference(key: ViewFramePreferenceKey.self,
                              value: .bounds) {
            [id: $0]
        }
    }
}


struct IfIsOutput: ViewModifier {
    let isOutput: Bool
    
    func body(content: Content) -> some View {
        if isOutput {
            content.trackFrame(id: String.DRAGGED_OUTPUT)
        } else {
            content
        }
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
                // log("GraphBaseView: onHover: document.keypressState.isSpacePressed: \(document.keypressState.isSpacePressed)")
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
