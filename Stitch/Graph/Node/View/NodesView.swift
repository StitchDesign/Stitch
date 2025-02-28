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
                self.allInputs = self.graph
                    .getCanvasItemsAtTraversalLevel()
                    .flatMap { canvasItem -> [InputNodeRowViewModel] in
                        canvasItem.inputViewModels
                    }
                
                self.connectedInputs = allInputs.filter { input in
                    guard input.nodeDelegate?.patchNodeViewModel?.patch != .wirelessReceiver else {
                        return false
                    }
                    return input.rowDelegate?.containsUpstreamConnection ?? false
                }
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
                
                PortPreviewPopoverView(inputs: allInputs,
                                       graphUI: document.graphUI)
                .border(.red)
            }
    }
}

struct PortPreviewPopoverView: View {
    let inputs: [InputNodeRowViewModel]
//    @Bindable var document: StitchDocumentViewModel
    @Bindable var graphUI: GraphUIState
    
    var body: some View {
        
        // If we have an open port preview
        if case let .input(portPreviewInputObserverCoordinate, portPreviewCanvasItemId) = graphUI.openPortPreview {
            ForEach(inputs) { (inputRowViewModel: InputNodeRowViewModel) in
                // And i
                let isPortPreviewInput = (inputRowViewModel.canvasItemDelegate?.id == portPreviewCanvasItemId)
                if isPortPreviewInput,
                   let rowObserver = inputRowViewModel.rowDelegate,
                   rowObserver.id == portPreviewInputObserverCoordinate,
                   let inputAnchor = inputRowViewModel.anchorPoint {
//                    Text("preview")
                    logInView("PortPreviewPopoverView: will open for input row view model  \(inputRowViewModel.id)")
                    logInView("PortPreviewPopoverView: inputAnchor: \(inputAnchor)")
                    
                    PortValuesPreviewView(rowObserver: rowObserver,
                                          rowViewModel: inputRowViewModel,
                                          nodeIO: .input)
//                    Text("Love me")
//                    .frame(width: 300, height: 300)
//                    .frame(minWidth: 300,
//                           maxWidth: 600,
//                           minHeight: 300,
//                           maxHeight: 600)
                    
//                    .frame(minHeight: NODE_ROW_HEIGHT * 2,
////                           maxHeight: 600)
//                           maxHeight: 200)
                
//                    .frame(width: 300)
                    
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onChange(of: proxy.frame(in: .global), initial: true) { _, newFrameData in
                                    log("PortPreviewPopoverView: newFrameData.origin: \(newFrameData.origin)")
                                    log("PortPreviewPopoverView: newFrameData.size: \(newFrameData.size)")
                                    
                                }
                        }
                    }
                    
                    .frame(width: 300, height: 300)
                    
                    // Need a geometry reader to know how about the stable-popover actually is?
                    
//                    .frame(width: 300,
//                           height: 600)
//                    .position(inputRowViewModel.anchorPoint ?? .zero)
//                    .position(inputAnchor - 100)
                    
                    // Where does this number come from?
                    // And how to do an arrow etc.?
//                    .position(inputAnchor - 50)
                    .position(x: inputAnchor.x - 75,
                              y: inputAnchor.y)
                    
                    // this doesn't read the size of the popover 
//                    .background {
//                        GeometryReader { proxy in
//                            Color.clear
//                                .onChange(of: proxy.frame(in: .global), initial: true) { _, newFrameData in
//                                    log("PortPreviewPopoverView: newFrameData.origin: \(newFrameData.origin)")
//                                    log("PortPreviewPopoverView: newFrameData.size: \(newFrameData.size)")
//                                    
//                                }
//                        }
//                    }
                }
            }
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
