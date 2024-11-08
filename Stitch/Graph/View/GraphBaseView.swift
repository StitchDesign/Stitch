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
    let insertNodeMenuHiddenNodeId: NodeId?
    
    @MainActor
    var graph: GraphState {
        self.document.visibleGraph
    }

    var body: some View {
        // Our screen device measurements ignore the safe area,
        // so our touch-responsive interfaces must ignore them to.

        nodesAndCursor
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        self.document.graphMovement.zoomData.graphPinchToZoom(amount: value.magnification)
                    }
                    .onEnded { _ in
                        self.document.graphZoomEnded()
                    }
            )
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
        GraphGestureView(document: document) {
            NodesView(document: document,
                      graph: graph,
                      groupTraversedToChild: graphUI.groupTraversedToChild,
                      insertNodeMenuHiddenNodeId: insertNodeMenuHiddenNodeId)

                // zoom must come after offset
                // (rather than before; eg inside the NodesView)

                .background {
                    GraphGestureBackgroundView(document: document) {
                        Stitch.APP_BACKGROUND_COLOR
                            .edgesIgnoringSafeArea(.all)
                            // TODO: Location seems more accurate placed outside the UIKit wrapper,
                            // but doing so messes up rendering
                            .onTapGesture(count: 2) { newValue in
                                dispatch(GraphDoubleTappedAction(location: newValue))
                            }
                            .simultaneousGesture(TapGesture().onEnded {
                                dispatch(GraphTappedAction())
                            })
                    } // GraphGestureBackgroundView
                } // .background
        } // GraphGestureView
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

            // Selection box and cursor
            ExpansionBoxView(box: selectionState.expansionBox)

            if selectionState.isSelecting,
               let currentDrag = selectionState.dragCurrentLocation {
                CursorDotView(
                    currentDragLocation: currentDrag,
                    isFingerOnScreenSelection: selectionState.isFingerOnScreenSelection)
            }

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
                        // log("GraphBaseView: local frame: newValue: \(newValue)")
                        dispatch(SetDeviceScreenSize(frame: newValue))
                    }
                    .onChange(of: geometry.frame(in: .global), initial: true) { oldValue, newValue in
                        // log("GraphBaseView: global frame: newValue: \(newValue)")
                        dispatch(SetGraphYPosition(graphYPosition: newValue.origin.y))
                        dispatch(SetSidebarWidth(frame: newValue))
                    }
            }
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

func MOCK_NAMESPACE_ID() -> Namespace.ID {
    Namespace.init().wrappedValue
}

// struct GraphBaseView_REPL: View {
//     var body: some View {
//         let graphState = GraphState()
//         let node = splitterPatchNode(nodeId: TestIds._0,
//                                      position: .zero)
//         graphState.updatePatchNode(node)

//         let visibleNodes: VisibleNodes = [.patch(TestIds._0)]

//         let computedGraph = ComputedGraphState(visibleNodes: visibleNodes)
//         let project = devDefaultProject(graph: graphState, computedGraph: computedGraph)

//         return GraphBaseView(broadcastChoices: .init(),
//                              computedGraph: project.computedGraph,
//                              projectName: project.metadata.name,
//                              projectId: project.metadata.projectId,
//                              namespace: MOCK_NAMESPACE_ID(),
//                              previewWindowSize: graphState.previewWindowSize, previewingNodeChoice: nil)
//     }
// }

// struct GraphBase_Previews: PreviewProvider {
//     static var previews: some View {
//         GraphBaseView_REPL()
//             //            .previewInterfaceOrientation(.landscapeLeft)
//             .previewInterfaceOrientation(.portrait)
//     }
// }
