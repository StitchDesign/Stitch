//
//  GroupNodeView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/11/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct GroupNodeView: View {
    @Bindable var graph: GraphState
    @Bindable var viewModel: NodeViewModel
    let atleastOneCommentBoxSelected: Bool
    let activeGroupId: GroupNodeId?
    let activeIndex: ActiveIndex
    let adjustmentBarSessionId: AdjustmentBarSessionId

    var id: NodeId {
        self.viewModel.id
    }

    @MainActor
    var displayTitle: String {
        self.viewModel.displayTitle
    }

    @MainActor
    var isSelected: Bool {
        viewModel.isSelected
    }

    var body: some View {
        NodeView(graph: graph,
                 node: viewModel,
                 isSelected: isSelected,
                 atleastOneCommentBoxSelected: atleastOneCommentBoxSelected,
                 activeGroupId: activeGroupId,
                 canAddInput: false,
                 canRemoveInput: false,
                 boundsReaderDisabled: false,
                 usePositionHandler: true,
                 updateMenuActiveSelectionBounds: false,
                 isHiddenDuringAnimation: false,
                 inputsViews: inputsViews,
                 outputsViews: outputsViews)
    }

    @MainActor
    func inputsViews() -> some View {
        DefaultNodeRowView(graph: graph,
                           node: viewModel,
                           nodeIO: .input,
                           isNodeSelected: isSelected,
                           adjustmentBarSessionId: adjustmentBarSessionId)
    }

    @ViewBuilder @MainActor
    func outputsViews() -> some View {
        DefaultNodeRowView(graph: graph,
                           node: viewModel,
                           nodeIO: .output,
                           isNodeSelected: isSelected,
                           adjustmentBarSessionId: adjustmentBarSessionId)
    }
}
