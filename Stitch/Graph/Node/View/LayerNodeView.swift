//
//  LayerNodeView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/11/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LayerNodeView: View {
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerNode
    @Bindable var layerNode: LayerNodeViewModel
    let atleastOneCommentBoxSelected: Bool
    let activeGroupId: GroupNodeId?
    let activeIndex: ActiveIndex
    let boundsReaderDisabled: Bool
    let usePositionHandler: Bool
    let updateMenuActiveSelectionBounds: Bool
    let isHiddenDuringAnimation: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId

    var id: NodeId {
        self.viewModel.id
    }

    @MainActor
    var inputs: PortValuesList {
        self.viewModel.inputs
    }

    var displayTitle: String {
        self.viewModel.displayTitle
    }

    @MainActor
    var isSelected: Bool {
        viewModel.isSelected
    }

    var isHiddenLayer: Bool {
        !layerNode.hasSidebarVisibility
    }

    var body: some View {
        NodeView(graph: graph,
                 node: viewModel,
                 isSelected: isSelected,
                 atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                 activeGroupId: activeGroupId,
                 canAddInput: false,
                 canRemoveInput: false,
                 boundsReaderDisabled: boundsReaderDisabled,
                 usePositionHandler: usePositionHandler,
                 updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds,
                 isHiddenDuringAnimation: isHiddenDuringAnimation,
                 isHiddenLayer: isHiddenLayer,
                 inputsViews: inputsViews,
                 outputsViews: outputsViews)
    }

    @ViewBuilder @MainActor
    func inputsViews() -> some View {
        DefaultNodeRowView(graph: graph,
                           node: viewModel,
                           nodeIO: .input,
                           isNodeSelected: isSelected,
                           adjustmentBarSessionId: adjustmentBarSessionId)
            .padding([.trailing], NODE_ROW_HEIGHT)
    }

    @ViewBuilder @MainActor
    func outputsViews() -> some View {
        if let layer = self.viewModel.kind.getLayer,
           layer.supportsOutputs {
            VStack(alignment: .trailing,
                   spacing: SPACING_BETWEEN_NODE_ROWS) {

                DefaultNodeRowView(graph: graph,
                                   node: viewModel,
                                   nodeIO: .output,
                                   isNodeSelected: isSelected,
                                   adjustmentBarSessionId: adjustmentBarSessionId)
            }
        } else {
            EmptyView()
        }
    }

}
