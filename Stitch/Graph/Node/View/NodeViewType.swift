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

    var body: some View {
        switch node.nodeType {
        case .layer:
            // LayerNodes use `LayerInputOnGraphView`
            EmptyView()
                .onAppear {
                    fatalErrorIfDebug()
                }
            
        case .patch(let patchViewModel):
            PatchNodeView(graph: graph,
                          viewModel: node,
                          patchNode: patchViewModel,
                          atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                          activeGroupId: groupNodeFocused,
                          activeIndex: activeIndex,
                          boundsReaderDisabled: boundsReaderDisabled,
                          usePositionHandler: usePositionHandler,
                          updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds,
                          isHiddenDuringAnimation: isHiddenDuringAnimation,
                          adjustmentBarSessionId: adjustmentBarSessionId)
        case .group(let canvasViewModel):
            GroupNodeView(graph: graph,
                          nodeViewModel: node,
                          canvasViewModel: canvasViewModel,
                          atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                          activeGroupId: groupNodeFocused,
                          activeIndex: activeIndex,
                          adjustmentBarSessionId: adjustmentBarSessionId)
        }
    }
}

struct DefaultNodeInputView: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let isNodeSelected: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId
    
    var body: some View {
        DefaultNodeRowView(graph: graph,
                           node: node,
                           nodeRowDataList: node.getAllInputsObservers(),
                           nodeIO: .input,
                           adjustmentBarSessionId: adjustmentBarSessionId) { rowObserver, rowViewModel in
            NodeInputView(graph: graph,
                          rowObserver: rowObserver,
                          rowData: rowViewModel,
                          forPropertySidebar: false,
                          propertyIsSelected: false,
                          propertyIsAlreadyOnGraph: true,
                          isCanvasItemSelected: isNodeSelected)
        }
    }
}

struct DefaultNodeOutputView: View {
    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let isNodeSelected: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId
    
    var body: some View {
        DefaultNodeRowView(graph: graph,
                           node: node,
                           nodeRowDataList: node.getAllOutputsObservers(),
                           nodeIO: .output,
                           adjustmentBarSessionId: adjustmentBarSessionId) { rowObserver, rowViewModel in
            NodeOutputView(graph: graph,
                           rowObserver: rowObserver,
                           rowData: rowViewModel,
                           forPropertySidebar: false,
                           propertyIsSelected: false,
                           propertyIsAlreadyOnGraph: true,
                           isCanvasItemSelected: isNodeSelected)
        }
    }
}

struct DefaultNodeRowView<RowObserver, RowView>: View where RowObserver: NodeRowObserver,
                                                            RowView: View,
                                                            RowObserver.RowViewModelType.RowObserver == RowObserver {

    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let nodeRowDataList: [RowObserver]
    let nodeIO: NodeIO
    let adjustmentBarSessionId: AdjustmentBarSessionId
    @ViewBuilder var rowView: (RowObserver, RowObserver.RowViewModelType) -> RowView

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
        nodeRowDataList.isEmpty || isPatchWithNoRows
    }

    var alignment: HorizontalAlignment {
        switch nodeIO {
        case .input:
            return .leading
        case .output:
            return .trailing
        }
    }
    
    /// Filters row view models by node, rather than layer inspector.
    @MainActor func getRowViewModels() -> [RowObserver.RowViewModelType] {
        self.nodeRowDataList.compactMap { rowObserver in
            rowObserver.allRowViewModels.first {
                $0.id.isNode
            }
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
                ForEach(self.getRowViewModels()) { rowViewModel in
                    if let rowObserver = rowViewModel.rowDelegate {
                        self.rowView(rowObserver, rowViewModel)
                    }
                }
            }
        }
    }
}
