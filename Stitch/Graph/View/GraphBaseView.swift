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
        ZStack {

            // To cover top safe area that we don't ignore on iPad and that is gesture-inaccessbile
            Stitch.APP_BACKGROUND_COLOR
                .edgesIgnoringSafeArea(.all)
            
            //#if DEV_DEBUG
            //            // Use `ZStack { ...` instead of `ZStack(alignment: .top) { ...`
            //            // to get in exact screen center.
            //            Circle().fill(.cyan.opacity(0.5))
            //                .frame(width: 60, height: 60)
            //#endif

            nodesView
                          
            // IMPORTANT: applying .inspector outside of this ZStack causes displacement of graph contents when graph zoom != 1
            Circle().fill(Stitch.APP_BACKGROUND_COLOR.opacity(0.001))
                .frame(width: 1, height: 1)
                .inspector(isPresented: $store.showsLayerInspector) {
                    
                    LayerInspectorView(graph: graph,
                                       document: document)
                        .inspectorColumnWidth(LayerInspectorView.LAYER_INSPECTOR_WIDTH)
                }
        } // ZStack
        
        .modifier(ActivelyDrawnEdgeThatCanEnterInspector(
            graph: graph,
            scale: document.graphMovement.zoomData))
        
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
                        dispatch(SetGraphPosition(graphPosition: newValue.origin))
                        dispatch(SetSidebarWidth(frame: newValue))
                    }
            } // GeometryReader
        } // .background
    }
}

struct ActivelyDrawnEdgeThatCanEnterInspector: ViewModifier {
    
    @Bindable var graph: GraphState
    let scale: CGFloat
        
    // finds canvas input OR inspector input/field
    @MainActor
    func findEligibleInput(_ drawingObserver: EdgeDrawingObserver,
                                         draggedOutputRect: CGRect,
                                         geometry: GeometryProxy,
                                         preferences: [EdgeDraggedToInspector: Anchor<CGRect>]) -> EmptyView {
        
        guard let drawingGesture = drawingObserver.drawingGesture else {
            return EmptyView()
        }
        
        let dragLocation = drawingGesture.cursorLocationInGlobalCoordinateSpace
        
        var nearestInspectorInputs = [LayerInputType]()
        
        for preference in preferences {
            if case let .inspectorInputOrField(layerInputType) = preference.key,
               // Note: `areNear` *already* expands the 'hit area'
//                areNear(geometry[preference.value].origin,
                areNear(geometry[preference.value].mid,
                        dragLocation,
                        isInspectorInputOrFieldDetection: true) {
                
                log("findEligibleInspectorFieldOrRow: WAS NEAR: layerInputType: \(layerInputType)")
                nearestInspectorInputs.append(layerInputType)
            }
        } // for preference in ...
                
        
        DispatchQueue.main.async { [weak graph] in
            
            guard let graph = graph,
                  graph.edgeDrawingObserver.drawingGesture.isDefined else {
                log("findEligibleInspectorFieldOrRow: no longer have an output drag")
                return
            }
            
            if let outputNodeId = drawingGesture.outputId.graphItemType.getCanvasItemId,
               let dragLocationInNodesViewCoordinateSpace = graph.dragLocationInNodesViewCoordinateSpace {
                graph.findEligibleCanvasInput(
                    cursorLocation: dragLocationInNodesViewCoordinateSpace,
                    cursorNodeId: outputNodeId)
            }
            
            let hadEligibleInspectorInputOrField = drawingObserver.nearestEligibleEdgeDestination?.getInspectorInputOrField.isDefined ?? false
            
            if nearestInspectorInputs.isEmpty,
               hadEligibleInspectorInputOrField {
                log("findEligibleInspectorFieldOrRow: NO inspector inputs/fields")
                drawingObserver.nearestEligibleEdgeDestination = nil
            } else if let nearestInspectorInput = nearestInspectorInputs.last {
                log("findEligibleInspectorFieldOrRow: found inspector input/field: \(nearestInspectorInput)")
                drawingObserver.nearestEligibleEdgeDestination = .inspectorInputOrField(nearestInspectorInput)
            }
            
            // After we've set or wiped the nearestEligible input,
            // *animate* the port color change:
            withAnimation(.linear(duration: DrawnEdge.ANIMATION_DURATION)) {
                graph
                    .getOutputRowObserver(drawingGesture.outputId.asNodeIOCoordinate)?
                    .updateRowViewModelsPortColor(selectedEdges: graph.selectedEdges,
                                                  selectedCanvasItems: graph.selectedCanvasItems,
                                                  drawingObserver: drawingObserver)
            }
        }
                
        return EmptyView()
    }
    
    @Environment(\.appTheme) var theme
        
    // Note: the rules for the color of an actively dragged edge are simple:
    // gray if no eligible input, else highlighted-loop if a loop, else highlighted.
    @MainActor
    func color(_ outputRowViewModel: OutputNodeRowViewModel) -> PortColor {
        if !graph.edgeDrawingObserver.nearestEligibleEdgeDestination.isDefined {
            return .noEdge
        } else if (outputRowViewModel.rowDelegate?.hasLoopedValues ?? false) {
            return .highlightedLoopEdge
        } else {
            return .highlightedEdge
        }
    }
    
    // TODO: is this really appropriate even for actively dragged circuit edges? ... there's no such thing as an an
    @MainActor
    var inputAnchorData: EdgeAnchorDownstreamData? {
        
        // just need the nearest eligible canvas/inspector's input node row view model
        
        switch graph.edgeDrawingObserver.nearestEligibleEdgeDestination {
            
        case .none:
            return nil
        
        case .canvasInput(let inputNodeRowViewModel):
            return EdgeAnchorDownstreamData(from: inputNodeRowViewModel)
        
        case .inspectorInputOrField(let layerInputType):
            if let firstFocusedLayer = graph.inspectorFocusedLayers.first,
               let nearestEligibleInputOrFieldRowViewModel: InputNodeRowViewModel = graph.getInputRowViewModel(for:
                     .init(graphItemType: .layerInspector(.keyPath(layerInputType)),
                           nodeId: firstFocusedLayer.asLayerNodeId.asNodeId,
                           // All layer inputs/input-fields have 0
                           portId: 0)) {
                return EdgeAnchorDownstreamData(from: nearestEligibleInputOrFieldRowViewModel)
            } else {
                return nil
            }
        }
    }
    
    @MainActor @ViewBuilder
    func body(content: Content) -> some View {
        // TODO: is this acceptable for perf?
        content
            .overlayPreferenceValue(EdgeDraggedToInspectorPreferenceKey.self) { preferences in
                GeometryReader { geometry in
                    if let drawingGesture = graph.edgeDrawingObserver.drawingGesture,
                       // The output from which the currently-dragged edge originates
                       let draggedOutputPref = preferences[.draggedOutput(drawingGesture.outputId.asNodeIOCoordinate)],
                       let outputRowViewModel = self.graph.getOutputRowViewModel(for: drawingGesture.outputId) {
                        
                        // Location of dragged edge's end, i.e. user's cursor position
                        let draggedOutputRect: CGRect = geometry[draggedOutputPref]
                        
                        // Always draw the
                        let pointTo = drawingGesture.cursorLocationInGlobalCoordinateSpace
                        
                        
                        if let downstreamNode = graph.getNode(drawingGesture.outputId.nodeId),
                           let upstreamCanvasItem = outputRowViewModel.canvasItemDelegate,
                            let outputAnchorData = EdgeAnchorUpstreamData(
                                from: upstreamCanvasItem.outputPortUIViewModels,
                                upstreamNodeId: upstreamCanvasItem.id.nodeId,
                                inputRowViewModelsOnDownstreamNode: downstreamNode.allInputViewModels),
                           let outputPortAddress = outputRowViewModel.portUIViewModel.portAddress,
                           let outputNodeId = outputRowViewModel.canvasItemDelegate?.id
//                            ,
//                           let pointFrom = outputRowViewModel.portUIViewModel.anchorPoint
                        {
                            
                            // Note:
                            let pointFrom = draggedOutputRect.mid
                            
                            logInView("EdgeFromDraggedOutputView: pointFrom: \(pointFrom)")
                            logInView("EdgeFromDraggedOutputView: pointTo: \(pointTo)")
                            
                            let edge = PortEdgeUI(from: outputPortAddress,
                                                  to: .init(portId: -1, // Nonsense
                                                            canvasId: outputNodeId))
                            
                            let color = self.color(outputRowViewModel)
                            
                            EdgeView(edge: edge,
                                     pointFrom: pointFrom,
                                     pointTo: pointTo,
                                     color: color.color(theme),
                                     isActivelyDragged: true, // always true for actively-dragged edge
                                     firstFrom: outputAnchorData.firstUpstreamOutput.anchorPoint ?? .zero,
                                     firstTo: inputAnchorData?.firstInput.anchorPoint ?? .zero,
                                     lastFrom: outputAnchorData.lastUpstreamRowOutput.anchorPoint ?? .zero,
                                     lastTo: inputAnchorData?.lastInput.anchorPoint ?? .zero,
                                     firstFromWithEdge: outputAnchorData.firstConnectedUpstreamOutput?.anchorPoint?.y,
                                     lastFromWithEdge: outputAnchorData.lastConnectedUpstreamOutput?.anchorPoint?.y,
                                     firstToWithEdge: inputAnchorData?.firstConnectedInput.anchorPoint?.y,
                                     lastToWithEdge: inputAnchorData?.lastConectedInput.anchorPoint?.y,
                                     totalOutputs: outputAnchorData.totalOutputs,
                                     // we never animate the actively dragged edge
                                     edgeAnimationEnabled: false,
                                     edgeScaleEffect: scale)
                            .animation(.linear(duration: DrawnEdge.ANIMATION_DURATION),
                                       value: color)
                        }
                        
//                        // Render the actively-drawn-edge
//                        CurveLine(from: draggedOutputRect.mid,
//                                  to: drawingGesture.dragLocation)
//                        .stroke(.red,
//                                style: StrokeStyle(
//                                    // scale DOWN when we're zoomed out, i.e. simply apply the graph scale
//                                    lineWidth: LINE_EDGE_WIDTH * scale, //* self.document.graphMovement.zoomData,
//                                    lineCap: .round,
//                                    lineJoin: .round))
                        
                        findEligibleInput(
                            graph.edgeDrawingObserver,
                            draggedOutputRect: draggedOutputRect,
                            geometry: geometry,
                            preferences: preferences
                        )
                    } // if let draggedOutputPref
                } // GeometryReader
            } // overlayPreferenceValue
    } // body(content:)

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
