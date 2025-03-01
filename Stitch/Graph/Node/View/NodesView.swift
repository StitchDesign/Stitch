//
//  NodesView.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/14/22.
//

import SwiftUI
import StitchSchemaKit

struct NodesView: View {
    static let coordinateNameSpace = "NODESVIEW"
    
    @Bindable var document: StitchDocumentViewModel
    
    // Manages visible nodes array to animate instances when a group node changes
    @Bindable var graph: GraphState
    
    // animation state for group node traversals
    let groupTraversedToChild: Bool


    private var visibleNodesViewModel: VisibleNodesViewModel {
        self.graph.visibleNodesViewModel
    }
    
    @MainActor
    private var graphUI: GraphUIState {
        self.graph.graphUI
    }
    
    // Finds a group node's offset from center, used for animating
    // group node traversals
    // TODO: group node location for transition
    var groupNodeLocation: CGPoint {
        .zero
        //        guard let groupNodeFocused = groupNodeFocused,
        //              let groupNode: GroupNode = groupNodesState[groupNodeFocused] else {
        //            return CGPoint.zero
        //        }
        //        return getNodeOffset(node: groupNode.schema,
        //                             graphViewFrame: graphFrame,
        //                             scale: zoom)
    }
    
    var body: some View {
        let currentNodePageData = self.graph.visibleNodesViewModel
            .getViewData(groupNodeFocused: graphUI.groupNodeFocused?.groupNodeId) ?? .init(localPosition: graph.localPosition)
                
        // CommentBox needs to be affected by graph offset and zoom
//         but can live somewhere else?
        InfiniteCanvas(graph: graph,
                       existingCache: graph.visibleNodesViewModel.infiniteCanvasCache,
                       needsInfiniteCanvasCacheReset: graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset) {
            
            //                        commentBoxes
            
            nodesOnlyView(nodePageData: currentNodePageData)
        }
           .modifier(CanvasEdgesViewModifier(document: document,
                                             graph: graph,
                                             graphUI: graphUI))
        
           .transition(.groupTraverse(isVisitingChild: groupTraversedToChild,
                                      nodeLocation: groupNodeLocation,
                                      graphOffset: .zero))
        
           .coordinateSpace(name: Self.coordinateNameSpace)
        
           .modifier(GraphMovementViewModifier(graphMovement: graph.graphMovement,
                                               currentNodePage: currentNodePageData,
                                               graph: graph,
                                               groupNodeFocused: graphUI.groupNodeFocused))
        // should come after edges, so that edges are offset, scaled etc.
           .modifier(StitchUIScrollViewModifier(document: document))
    }
    
    // TODO: better location for CommentBoxes?
//    var commentBoxes: some View {
//        ForEach(graph.commentBoxesDict.toValuesArray, id: \.id) { box in
//            CommentBoxView(
//                graph: graph,
//                box: box,
//                isSelected: selection.selectedCommentBoxes.contains(box.id))
//            .zIndex(box.zIndex)
//        }
//    }
    
    @MainActor
    func nodesOnlyView(nodePageData: NodePageData) -> some View {
        NodesOnlyView(document: document,
                      graph: graph,
                      graphUI: graphUI,
                      nodePageData: nodePageData)
    }
}

struct CanvasEdgesViewModifier: ViewModifier {
    @State private var allInputs: [InputNodeRowViewModel] = []
    @State private var allOutputs: [OutputNodeRowViewModel] = []
    @State private var connectedInputs: [InputNodeRowViewModel] = []
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var graphUI: GraphUIState
    
    @MainActor
    func connectedEdgesView(allConnectedInputs: [InputNodeRowViewModel]) -> some View {
        GraphConnectedEdgesView(graph: graph,
                                graphUI: graphUI,
                                allConnectedInputs: allConnectedInputs)
    }
    
    @MainActor
    func edgeDrawingView(inputs: [InputNodeRowViewModel],
                         graph: GraphState) -> some View {
        EdgeDrawingView(graph: graph,
                        edgeDrawingObserver: graph.edgeDrawingObserver,
                        inputsAtThisTraversalLevel: inputs)
    }
    
    func body(content: Content) -> some View {
        // Including "possible" inputs enables edge animation
        let candidateInputs: [InputNodeRowViewModel] = graphUI.edgeEditingState?.possibleEdges.compactMap {
            let inputData = $0.edge.to
            
            guard let node = self.graph.getCanvasItem(inputData.canvasId),
                  let inputRow = node.inputViewModels[safe: inputData.portId] else {
                return nil
            }
            
            return inputRow
        } ?? []
        
        return content
        // Moves expensive computation here to reduce render cycles
            .onChange(of: graph.graphUpdaterId, initial: true) {
                // log("CanvasEdgesViewModifier: .onChange(of: self.graph.graphUpdaterId)")
                let canvasItemsAtThisTraversalLevel = self.graph.getCanvasItemsAtTraversalLevel()
                
                self.allInputs = canvasItemsAtThisTraversalLevel
                    .flatMap { canvasItem -> [InputNodeRowViewModel] in
                        canvasItem.inputViewModels
                    }
                
                self.connectedInputs = allInputs.filter { input in
                    guard input.nodeDelegate?.patchNodeViewModel?.patch != .wirelessReceiver else {
                        return false
                    }
                    return input.rowDelegate?.containsUpstreamConnection ?? false
                }
                
                self.allOutputs = canvasItemsAtThisTraversalLevel
                    .flatMap { $0.outputViewModels }
            }
            .background {
                // Using background ensures edges z-index are always behind ndoes
                connectedEdgesView(allConnectedInputs: connectedInputs + candidateInputs)
            }
            .overlay {
                edgeDrawingView(inputs: allInputs,
                                graph: self.graph)
                
                EdgeInputLabelsView(inputs: allInputs,
                                    document: document,
                                    graphUI: document.graphUI)
                
                
                
                if let openPortPreview = graphUI.openPortPreview {
                    
                    // Find the input or output that has the matching canvas-item-id and row-observer-id
                    
//                    
//                    if let rowViewModel = (openPortPreview.nodeIO == .input ? allInputs : allOutputs).first { rowViewModel in
//                        rowViewModel.canvasItemDelegate?.id == openPortPreview.canvasItemId
//                        && rowViewModel?.rowDelegate?.id == openPortPreview.port
//                    } {
//                        PortPreviewPopoverView(rowViewModel: rowViewModel,
//                                               nodeIO: openPortPreview.nodeIO)
//                    }
//                    
                    switch openPortPreview.nodeIO {
                    case .input:
                        if let rowViewModel = allInputs.first(where: { rowViewModel in
                            rowViewModel.canvasItemDelegate?.id == openPortPreview.canvasItemId
                            && rowViewModel.rowDelegate?.id == openPortPreview.port
                        }) {
                            PortPreviewPopoverView(rowViewModel: rowViewModel,
                                                   nodeIO: .input)
                        }
//                        InputPreviewPopoverView(ports: allInputs,
//                                                graphUI: graphUI)
                    case .output:
                        if let rowViewModel = allOutputs.first(where: { rowViewModel in
                            rowViewModel.canvasItemDelegate?.id == openPortPreview.canvasItemId
                            && rowViewModel.rowDelegate?.id == openPortPreview.port
                        }) {
                            PortPreviewPopoverView(rowViewModel: rowViewModel,
                                                   nodeIO: .output)
                        }
//                        OutputPreviewPopoverView(ports: allOutputs,
//                                                 graphUI: graphUI)
                    }
                }
            }
    }
}


let PORT_PREVIEW_POPOVER_MAX_HEIGHT: CGFloat = 420

//struct PortPreviewPopoverView<NodeRowObserverType: NodeRowObserver>: View {
struct InputPreviewPopoverView: View {

    let ports: [InputNodeRowViewModel]
    @Bindable var graphUI: GraphUIState
    
    @State private var width: CGFloat = .zero
    
    var body: some View {
        
        // If we have an open port preview
        if let openPortPreview = graphUI.openPortPreview,
           openPortPreview.nodeIO == .input {
//        if case let .input(portPreviewInputObserverCoordinate, portPreviewCanvasItemId) = graphUI.openPortPreview {
            ForEach(ports) { inputRowViewModel in
                let portPreviewCanvasItemId = openPortPreview.canvasItemId
                
                 if inputRowViewModel.canvasItemDelegate?.id == openPortPreview.canvasItemId,
                    let rowObserver = inputRowViewModel.rowDelegate,
                    rowObserver.id == openPortPreview.port,
                    let anchor = inputRowViewModel.anchorPoint {
                    
                     
                     ZStack {
                         Rectangle().fill(.clear)
                             .frame(width: 30, height: 30)
                             .background(.ultraThinMaterial)
 //                            .background(.red)
                             .rotationEffect(.degrees(45))
                             .position(x: anchor.x - self.width/2,
                                       y: anchor.y)
                             .offset(x: self.width/2 - 36)
                                                 
                         PortValuesPreviewView(
                            rowObserver: rowObserver,
                            rowViewModel: inputRowViewModel,
                            nodeIO: openPortPreview.nodeIO)
                         
                         .background {
                             GeometryReader { proxy in
                                 Color.clear
                                 // IMPORTANT: use .local frame, since .global is affected by zooming and creates infinite loop
                                     .onChange(of: proxy.frame(in: .local), initial: true) { _, newFrameData in
                                         log("InputPreviewPopoverView: newFrameData.size.width: \(newFrameData.size.width)")
                                         self.width = newFrameData.size.width
                                     }
                             }
                         }
                         .frame(maxHeight: PORT_PREVIEW_POPOVER_MAX_HEIGHT)
 //                        .fixedSize(horizontal: true, vertical: true)
                         .fixedSize(horizontal: false, vertical: true)
                         
                         // self.width/1.65 is actually not a consistent
                         .position(x: anchor.x - self.width/2,
                                   y: anchor.y)
                         .offset(x: -32)
                         
                     } // ZStack
                     
                }
            }
        }
    }
}

struct OutputPreviewPopoverView: View {

    let ports: [OutputNodeRowViewModel]
    @Bindable var graphUI: GraphUIState
    
    @State private var width: CGFloat = .zero
    
    var body: some View {
        
        // If we have an open port preview
        if let openPortPreview = graphUI.openPortPreview,
           openPortPreview.nodeIO == .output {
            ForEach(ports) { outputRowViewModel in
                let portPreviewCanvasItemId = openPortPreview.canvasItemId
                
                 if outputRowViewModel.canvasItemDelegate?.id == openPortPreview.canvasItemId,
                    let rowObserver = outputRowViewModel.rowDelegate,
                    rowObserver.id == openPortPreview.port,
                    let anchor = outputRowViewModel.anchorPoint {
                    
                     ZStack {
                         Rectangle().fill(.clear)
                             .frame(width: 30, height: 30)
                             .background(.ultraThinMaterial)
                             .rotationEffect(.degrees(45))
                             .position(x: anchor.x + self.width/2,
                                       y: anchor.y)
                             .offset(x: -self.width/2 + 36)
                                                 
                         PortValuesPreviewView(
                            rowObserver: rowObserver,
                            rowViewModel: outputRowViewModel,
                            nodeIO: openPortPreview.nodeIO)
                         
                         .background {
                             GeometryReader { proxy in
                                 Color.clear
                                 // IMPORTANT: use .local frame, since .global is affected by zooming and creates infinite loop
                                     .onChange(of: proxy.frame(in: .local), initial: true) { _, newFrameData in
                                         log("OutputPreviewPopoverView: newFrameData.size.width: \(newFrameData.size.width)")
                                         self.width = newFrameData.size.width
                                     }
                             }
                         }
                         .frame(maxHeight: PORT_PREVIEW_POPOVER_MAX_HEIGHT)
                         .fixedSize(horizontal: false, vertical: true)
                         .position(x: anchor.x + self.width/2,
                                   y: anchor.y)
                         .offset(x: 32)
                         
                     } // ZStack
                     
                }
            }
        }
    }
}

struct PortPreviewPopoverView<NodeRowObserverType: NodeRowObserver>: View {

    let rowViewModel: NodeRowObserverType.RowViewModelType
    let nodeIO: NodeIO
    
    @State private var width: CGFloat = .zero
    
    var body: some View {
        if let rowObserver = rowViewModel.rowDelegate,
           let anchor = rowViewModel.anchorPoint {
            
            let positionAdjustment: CGFloat = nodeIO == .input ? -self.width/2 : self.width/2
            let arrowOffsetAdjustment: CGFloat = nodeIO == .input ? (self.width/2 - 36) : (-self.width/2 + 36)
            let popoverOffsetAdjustment: CGFloat = nodeIO == .input ? -32 : 32
            
            ZStack {
                Rectangle().fill(.clear)
                    .frame(width: 30, height: 30)
                    .background(.ultraThinMaterial)
                    .rotationEffect(.degrees(45))
                    .position(x: anchor.x + positionAdjustment,
                              y: anchor.y)
                    .offset(x: arrowOffsetAdjustment)
                
                PortValuesPreviewView(
                    rowObserver: rowObserver,
                    rowViewModel: rowViewModel,
                    nodeIO: nodeIO)
                
                .background {
                    GeometryReader { proxy in
                        Color.clear
                        // IMPORTANT: use .local frame, since .global is affected by zooming and creates infinite loop
                            .onChange(of: proxy.frame(in: .local), initial: true) { _, newFrameData in
                                log("PortPreviewPopoverView: newFrameData.size.width: \(newFrameData.size.width)")
                                self.width = newFrameData.size.width
                            }
                    }
                }
                .frame(maxHeight: PORT_PREVIEW_POPOVER_MAX_HEIGHT)
                .fixedSize(horizontal: false, vertical: true)
                .position(x: anchor.x + positionAdjustment,
                          y: anchor.y)
                .offset(x: popoverOffsetAdjustment)
                
            } // ZStack
            
        }
    }
}



struct EdgeInputLabelsView: View {
    let inputs: [InputNodeRowViewModel]
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graphUI: GraphUIState

    var body: some View {
        let showLabels = document.graphUI.edgeEditingState?.labelsShown ?? false
        
        if let nearbyCanvasItem: CanvasItemId = document.graphUI.edgeEditingState?.nearbyCanvasItem {
            ForEach(inputs) { inputRowViewModel in
                
                // Doesn't seem to be needed? Checking the canvasItemDelegate seems to work well
                // visibleNodeId property checks for group splitter inputs
                // let isInputForNearbyNode = inputRowViewModel.visibleNodeIds.contains(nearbyCanvasItem)
                
                let isInputOnNearbyCanvasItem = inputRowViewModel.canvasItemDelegate?.id == nearbyCanvasItem
                let isVisible = isInputOnNearbyCanvasItem && showLabels
                
                EdgeEditModeLabelsView(document: document,
                                       portId: inputRowViewModel.id.portId)
                .position(inputRowViewModel.anchorPoint ?? .zero)
                .opacity(isVisible ? 1 : 0)
                .animation(.linear(duration: .EDGE_EDIT_MODE_NODE_UI_ELEMENT_ANIMATION_LENGTH),
                           value: isVisible)
            }
        } else {
            EmptyView()
        }
    }
}
