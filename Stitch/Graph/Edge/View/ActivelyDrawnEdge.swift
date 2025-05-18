//
//  ActivelyDrawnEdge.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/18/25.
//

import SwiftUI

struct ActivelyDrawnEdge: ViewModifier {
    
    @Environment(\.appTheme) var theme
    
    @Bindable var graph: GraphState
    let scale: CGFloat
    
    // finds canvas input OR inspector input/field
    @MainActor
    func findEligibleInput(_ drawingObserver: EdgeDrawingObserver,
                           drawingGesture: OutputDragGesture,
                           draggedOutputRect: CGRect,
                           geometry: GeometryProxy,
                           preferences: [EdgeDraggedToInspector: Anchor<CGRect>]) -> EmptyView {
                
        // TODO: do we risk a retain cycle here?
        DispatchQueue.main.async { [weak graph] in
            
            guard let graph = graph,
                  graph.edgeDrawingObserver.drawingGesture.isDefined else {
                // log("findEligibleInspectorFieldOrRow: no longer have an output drag")
                return
            }
            
            
            if let outputNodeId = drawingGesture.outputId.graphItemType.getCanvasItemId,
               let dragLocationInNodesViewCoordinateSpace = graph.dragLocationInNodesViewCoordinateSpace {
                graph.findEligibleCanvasInput(
                    cursorLocation: dragLocationInNodesViewCoordinateSpace,
                    cursorNodeId: outputNodeId)
            }
            
            graph.findEligibleInspectorInputOrField(drawingObserver: drawingObserver,
                                                    drawingGesture: drawingGesture,
                                                    geometry: geometry,
                                                    preferences: preferences)
        }
        
        return EmptyView()
    }
    
    
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
                    if let drawingGesture: OutputDragGesture = graph.edgeDrawingObserver.drawingGesture,
                       // The output from which the currently-dragged edge originates
                       let draggedOutputPref = preferences[.draggedOutput(drawingGesture.outputId.asNodeIOCoordinate)],
                       let outputRowViewModel = self.graph.getOutputRowViewModel(for: drawingGesture.outputId) {
                        
                        // Location of dragged edge's end, i.e. user's cursor position
                        let draggedOutputRect: CGRect = geometry[draggedOutputPref]
                        
                        let pointTo = drawingGesture.cursorLocationInGlobalCoordinateSpace
                        
                        if let downstreamNode = graph.getNode(drawingGesture.outputId.nodeId),
                           let upstreamCanvasItem = outputRowViewModel.canvasItemDelegate,
                           let outputAnchorData = EdgeAnchorUpstreamData(
                            from: upstreamCanvasItem.outputPortUIViewModels,
                            upstreamNodeId: upstreamCanvasItem.id.nodeId,
                            inputRowViewModelsOnDownstreamNode: downstreamNode.allInputViewModels),
                           let outputPortAddress = outputRowViewModel.portUIViewModel.portAddress,
                           let outputNodeId = outputRowViewModel.canvasItemDelegate?.id
                        
                        // TODO: previously the actively-drawn-edge used a NodesView-coordinate-space poiint
                        // , let pointFrom = outputRowViewModel.portUIViewModel.anchorPoint
                        {
                            
                            let pointFrom = draggedOutputRect.mid
                            
                            // logInView("EdgeFromDraggedOutputView: pointFrom: \(pointFrom)")
                            // logInView("EdgeFromDraggedOutputView: pointTo: \(pointTo)")
                            
                            // TODO: `EdgeView` for actively-drawn edges does not need to take the full `PortEdgeUI` ?
                            let edge = PortEdgeUI(from: outputPortAddress,
                                                  to: .init(portId: -1, // Nonsense
                                                            canvasId: outputNodeId))
                            
                            let color = self.color(outputRowViewModel)
                            
                            EdgeView(edge: edge,
                                     pointFrom: pointFrom,
                                     pointTo: pointTo,
                                     color: color.color(theme),
                                     isActivelyDragged: true, // Always true for actively-dragged edge
                                     firstFrom: outputAnchorData.firstUpstreamOutput.anchorPoint ?? .zero,
                                     firstTo: inputAnchorData?.firstInput.anchorPoint ?? .zero,
                                     lastFrom: outputAnchorData.lastUpstreamRowOutput.anchorPoint ?? .zero,
                                     lastTo: inputAnchorData?.lastInput.anchorPoint ?? .zero,
                                     firstFromWithEdge: outputAnchorData.firstConnectedUpstreamOutput?.anchorPoint?.y,
                                     lastFromWithEdge: outputAnchorData.lastConnectedUpstreamOutput?.anchorPoint?.y,
                                     firstToWithEdge: inputAnchorData?.firstConnectedInput.anchorPoint?.y,
                                     lastToWithEdge: inputAnchorData?.lastConectedInput.anchorPoint?.y,
                                     totalOutputs: outputAnchorData.totalOutputs,
                                     // We never animate the actively dragged edge
                                     edgeAnimationEnabled: false,
                                     edgeScaleEffect: scale)
                            .animation(.linear(duration: DrawnEdge.ANIMATION_DURATION),
                                       value: color)
                        }
                        
                        findEligibleInput(graph.edgeDrawingObserver,
                                          drawingGesture: drawingGesture,
                                          draggedOutputRect: draggedOutputRect,
                                          geometry: geometry,
                                          preferences: preferences)
                        
                    } // if let draggedOutputPref
                } // GeometryReader
            } // overlayPreferenceValue
    } // body(content:)
    
}
