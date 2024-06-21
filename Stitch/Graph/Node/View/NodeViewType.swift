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
            
        case .group:
            GroupNodeView(graph: graph,
                          viewModel: node,
                          atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                          activeGroupId: groupNodeFocused,
                          activeIndex: activeIndex,
                          adjustmentBarSessionId: adjustmentBarSessionId)
        }
    }
}

struct DefaultNodeRowView: View {

    @Bindable var graph: GraphState
    @Bindable var node: NodeViewModel
    let nodeIO: NodeIO
    let isNodeSelected: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId

    var id: NodeId {
        self.node.id
    }
    
    @MainActor
    var nodeRowDataList: NodeRowObservers {
        self.node.getRowObservers(nodeIO)
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

    var body: some View {
        VStack(alignment: self.alignment,
               spacing: SPACING_BETWEEN_NODE_ROWS) {
            // If no rows, create a dummy view to create some empty space
            if hasEmptyRows {
                Color.clear
                    .frame(width: NODE_BODY_SPACING,
                           height: NODE_ROW_HEIGHT)
            } else {
                ForEach(nodeRowDataList) { data in
                    if let coordinate = data.portViewType {
                        self.rowView(data: data,
                                     coordinateType: coordinate)
                            .modifier(EdgeEditModeViewModifier(graphState: graph,
                                                               coordinate: coordinate))
                    } else {
                        EmptyView()
                            .onAppear {
                                fatalErrorIfDebug()
                            }
                    }
                }
            }
        }
    }

    @ViewBuilder @MainActor
    func rowView(data: NodeRowObserver,
                 coordinateType: PortViewType) -> some View {
        NodeInputOutputView(
            graph: graph,
            node: node,
            rowData: data,
            coordinateType: coordinateType,
            nodeKind: nodeKind,
            isCanvasItemSelected: isNodeSelected,
            adjustmentBarSessionId: adjustmentBarSessionId)
    }
}
