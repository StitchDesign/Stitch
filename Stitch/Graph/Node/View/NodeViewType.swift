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
    let groupNodeFocused: GroupNodeId?
    let adjustmentBarSessionId: AdjustmentBarSessionId

    var boundsReaderDisabled: Bool = false
    var usePositionHandler: Bool = true

    // Only true for the fake-node that lives in ContentView
    var updateMenuActiveSelectionBounds: Bool = false

    // Only true for the "real node" while the insert-node animation is in progress
    var isHiddenDuringAnimation: Bool = false
    
    @MainActor
    var isSelected: Bool {
        canvasNode.isSelected
    }
    
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
                 isSelected: isSelected,
                 atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                 activeGroupId: groupNodeFocused,
                 canAddInput: node.canAddInputs,
                 canRemoveInput: node.canRemoveInputs,
                 sortedUserTypeChoices: sortedUserTypeChoices,
                 boundsReaderDisabled: boundsReaderDisabled,
                 usePositionHandler: usePositionHandler,
                 updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds,
                 isHiddenDuringAnimation: isHiddenDuringAnimation,
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
                WirelessPortView(isOutput: false, id: node.id)
                    .padding(.trailing, NODE_BODY_SPACING)
            } else {
                DefaultNodeInputView(graph: graph,
                                     node: node,
                                     canvas: canvasNode,
                                     isNodeSelected: isSelected,
                                     adjustmentBarSessionId: adjustmentBarSessionId)
            }
        }
    }

    @ViewBuilder @MainActor
    func outputsViews() -> some View {
        VStack(alignment: .trailing,
               spacing: SPACING_BETWEEN_NODE_ROWS) {

            if self.node.patch == .wirelessBroadcaster {
                WirelessPortView(isOutput: true, id: node.id)
                    .padding(.leading, NODE_BODY_SPACING)
            } else {
                DefaultNodeOutputView(graph: graph,
                                      node: node,
                                      canvas: canvasNode,
                                      isNodeSelected: isSelected,
                                      adjustmentBarSessionId: adjustmentBarSessionId)
            }
        }
    }
}

struct DefaultNodeInputView: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvas: CanvasItemViewModel
    let isNodeSelected: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId
    
    var body: some View {
        DefaultNodeRowView(graph: graph,
                           node: node,
                           rowViewModels: canvas.inputViewModels,
                           nodeIO: .input,
                           adjustmentBarSessionId: adjustmentBarSessionId) { rowObserver, rowViewModel in
            NodeInputView(graph: graph, 
                          nodeId: node.id,
                          nodeKind: node.kind,
                          hasIncomingEdge: rowObserver.upstreamOutputCoordinate.isDefined,
                          rowObserverId: rowObserver.id,
                          rowObserver: rowObserver,
                          rowViewModel: rowViewModel,
                          fieldValueTypes: rowViewModel.fieldValueTypes,
                          layerInputObserver: nil, // Always nil, since this is a canvas item not an inspector-row
                          forPropertySidebar: false,
                          propertyIsSelected: false,
                          propertyIsAlreadyOnGraph: true, // Irrelevant?
                          isCanvasItemSelected: isNodeSelected,
                          label: rowObserver.label())
        }
    }
}

struct DefaultNodeOutputView: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    @Bindable var canvas: CanvasItemViewModel
    let isNodeSelected: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId
    
    var body: some View {
        DefaultNodeRowView(graph: graph,
                           node: node,
                           rowViewModels: canvas.outputViewModels,
                           nodeIO: .output,
                           adjustmentBarSessionId: adjustmentBarSessionId) { rowObserver, rowViewModel in
            NodeOutputView(graph: graph,
                           rowObserver: rowObserver,
                           rowViewModel: rowViewModel,
                           forPropertySidebar: false,
                           propertyIsSelected: false,
                           propertyIsAlreadyOnGraph: true,
                           isCanvasItemSelected: isNodeSelected, 
                           label: rowObserver.label())
        }
    }
}

struct DefaultNodeRowView<RowViewModel, RowView>: View where RowViewModel: NodeRowViewModel,
                                                             RowView: View {

    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let rowViewModels: [RowViewModel]
    let nodeIO: NodeIO
    let adjustmentBarSessionId: AdjustmentBarSessionId
    @ViewBuilder var rowView: (RowViewModel.RowObserver, RowViewModel) -> RowView

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
        VStack(alignment: self.alignment,
               spacing: SPACING_BETWEEN_NODE_ROWS) {
            // If no rows, create a dummy view to create some empty space
            if hasEmptyRows {
                Color.clear
                    .frame(width: NODE_BODY_SPACING,
                           height: NODE_ROW_HEIGHT)
            } else {
                ForEach(self.rowViewModels) { rowViewModel in
                    if let rowObserver = rowViewModel.rowDelegate {
                        self.rowView(rowObserver, rowViewModel)
                    }
                }
            }
        }
    }
}
