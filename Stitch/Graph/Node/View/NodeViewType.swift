//
//  NodeViewType.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/11/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct NodeTypeView: View {
    // Use state rather than computed variable due to perf cost
    @State private var sortedUserTypeChoices = [UserVisibleType]()
    
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvasNode: CanvasItemViewModel
    let atleastOneCommentBoxSelected: Bool
    let activeIndex: ActiveIndex
    let groupNodeFocused: GroupNodeType?
    let isSelected: Bool

    var boundsReaderDisabled: Bool = false
    var usePositionHandler: Bool = true

    // Only true for the fake-node that lives in ContentView
    var updateMenuActiveSelectionBounds: Bool = false
    
    var userVisibleType: UserVisibleType? {
        self.node.userVisibleType
    }

    var userTypeChoices: Set<UserVisibleType> {
        self.node.patch?.availableNodeTypes ?? .init()
    }

    @MainActor
    var displayTitle: String {
        self.node.displayTitle
    }

    var body: some View {
        NodeView(node: canvasNode,
                 stitch: node,
                 document: document,
                 graph: graph,
                 nodeId: node.id,
                 isSelected: isSelected,
                 atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                 activeGroupId: groupNodeFocused,
                 canAddInput: node.canAddInputs,
                 canRemoveInput: node.canRemoveInputs,
                 sortedUserTypeChoices: sortedUserTypeChoices,
                 boundsReaderDisabled: boundsReaderDisabled,
                 usePositionHandler: usePositionHandler,
                 updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds,
                 inputsViews: inputsViews,
                 outputsViews: outputsViews)
        .onChange(of: self.node.patch, initial: true) {
            // Sorting is expensive so we control when this is calculated
            if let patchNode = self.node.patchNode {
                self.sortedUserTypeChoices = patchNode.getSortedUserTypeChoices()
            }
        }
    }
    
    @ViewBuilder @MainActor
    func inputsViews() -> some View {
        VStack(alignment: .leading,
               spacing: SPACING_BETWEEN_NODE_ROWS) {
            if self.node.patch == .wirelessReceiver {
                WirelessPortView(graph: graph,
                                 graphUI: document,
                                 isOutput: false,
                                 id: node.id)
                    .padding(.trailing, NODE_BODY_SPACING)
            } else {
                DefaultNodeInputView(graph: graph,
                                     document: document,
                                     node: node,
                                     canvas: canvasNode,
                                     isNodeSelected: isSelected)
            }
        }
    }

    @ViewBuilder @MainActor
    func outputsViews() -> some View {
        VStack(alignment: .trailing,
               spacing: SPACING_BETWEEN_NODE_ROWS) {

            if self.node.patch == .wirelessBroadcaster {
                WirelessPortView(graph: graph,
                                 graphUI: document,
                                 isOutput: true,
                                 id: node.id)
                    .padding(.leading, NODE_BODY_SPACING)
            } else {
                DefaultNodeOutputView(graph: graph,
                                      document: document,
                                      node: node,
                                      canvas: canvasNode,
                                      isNodeSelected: isSelected)
            }
        }
    }
}

struct DefaultNodeInputView: View {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var node: NodeViewModel
    @Bindable var canvas: CanvasItemViewModel
    let isNodeSelected: Bool
    
    var body: some View {
        DefaultNodeRowView(graph: graph,
                           node: node,
                           canvas: canvas,
                           rowViewModels: canvas.inputViewModels,
                           nodeIO: .input) { rowViewModel in
            if let rowObserver = node.getInputRowObserver(for: rowViewModel.id.portType) {
                let layerInputObserver: LayerInputObserver? = rowObserver.id.layerInput
                    .flatMap { node.layerNode?.getLayerInputObserver($0.layerInput) }
                
                //            NodeLayoutView(observer: rowViewModel) {
                HStack {
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowObserver: rowObserver,
                                    rowViewModel: rowViewModel)
                    
                    NodeInputView(graph: graph,
                                  graphUI: document,
                                  node: node,
                                  hasIncomingEdge: rowObserver.upstreamOutputCoordinate.isDefined,
                                  rowObserver: rowObserver,
                                  rowViewModel: rowViewModel,
                                  fieldValueTypes: rowViewModel.fieldValueTypes,
                                  // Pass down the layerInputObserver if we have a 'layer input on the canvas'
                                  canvasItem: canvas,
                                  layerInputObserver: layerInputObserver,
                                  forPropertySidebar: false, // Always false, since not an inspector-row
                                  propertyIsSelected: false,
                                  propertyIsAlreadyOnGraph: true, // Irrelevant?
                                  isCanvasItemSelected: isNodeSelected,
                                  label: rowObserver
                        .label(node: node,
                               currentTraversalLevel: document.groupNodeFocused?.groupNodeId,
                               graph: graph)
                    )
                }
            }
        }
    }
}

struct DefaultNodeOutputView: View {
    
    @Bindable var graph: GraphState
    @Bindable var document: StitchDocumentViewModel
    @Bindable var node: NodeViewModel
    @Bindable var canvas: CanvasItemViewModel
    let isNodeSelected: Bool
    
    var body: some View {
        DefaultNodeRowView(graph: graph,
                           node: node,
                           canvas: canvas,
                           rowViewModels: canvas.outputViewModels,
                           nodeIO: .output) { rowViewModel in
            if let rowObserver = node.getOutputRowObserver(for: rowViewModel.id.portType) {
                HStack {
                    NodeOutputView(graph: graph,
                                   graphUI: document,
                                   node: node,
                                   rowObserver: rowObserver,
                                   rowViewModel: rowViewModel,
                                   canvasItem: canvas,
                                   forPropertySidebar: false,
                                   propertyIsSelected: false,
                                   propertyIsAlreadyOnGraph: true,
                                   isCanvasItemSelected: isNodeSelected,
                                   label: rowObserver
                        .label(node: node,
                               currentTraversalLevel: document.groupNodeFocused?.groupNodeId,
                               graph: graph)
                    )
                    
                    NodeRowPortView(graph: graph,
                                    node: node,
                                    rowObserver: rowObserver,
                                    rowViewModel: rowViewModel)
                }
                .modifier(EdgeEditModeOutputHoverViewModifier(
                    graph: graph,
                    document: document,
                    outputCoordinate: .init(portId: rowViewModel.id.portId,
                                            canvasId: canvas.id)))
            }
        }
    }
}

struct DefaultNodeRowView<RowViewModel, RowView>: View where RowViewModel: NodeRowViewModel,
                                                             RowView: View {

    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvas: CanvasItemViewModel
    let rowViewModels: [RowViewModel]
    let nodeIO: NodeIO
    @ViewBuilder var rowView: (RowViewModel) -> RowView

    var id: NodeId {
        self.node.id
    }
    
    var nodeKind: NodeKind {
        self.node.kind
    }
    
    var isPatchWithNoRows: Bool {
        switch self.nodeKind {
        case .patch(let patch):
            switch nodeIO {
            case .input:
                return patch.nodeUIKind == .outputsOnly
            case .output:
                return patch.nodeUIKind == .inputsOnly
            }
        default:
            return false
        }
    }

    @MainActor
    var hasEmptyRows: Bool {
        rowViewModels.isEmpty || isPatchWithNoRows
    }

    var alignment: HorizontalAlignment {
        switch nodeIO {
        case .input:
            return .leading
        case .output:
            return .trailing
        }
    }
    
    var body: some View {
        VStack(alignment: self.alignment) {
            // If no rows, create a dummy view to create some empty space
            if hasEmptyRows {
                Color.clear
                    .frame(width: NODE_BODY_SPACING,
                           height: NODE_ROW_HEIGHT)
            } else {
                ForEach(self.rowViewModels) { rowViewModel in
                    self.rowView(rowViewModel)
                    // fixes issue where ports could have inconsistent height with no label
                        .height(NODE_ROW_HEIGHT + 8)
                        .onChange(of: rowViewModel.fieldValueTypes.first?.type) {
                            // Resets node sizing data when either node or portvalue types change
                            canvas.resetViewSizingCache()
                            graph.visibleNodesViewModel.needsInfiniteCanvasCacheReset = true
                        }
                }
            }
        }
    }
}
