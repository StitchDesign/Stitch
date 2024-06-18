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
    @Bindable var nodeViewModel: NodeViewModel
    @Bindable var canvasViewModel: CanvasNodeViewModel
    let atleastOneCommentBoxSelected: Bool
    let activeGroupId: GroupNodeId?
    let activeIndex: ActiveIndex
    let adjustmentBarSessionId: AdjustmentBarSessionId

    var id: NodeId {
        self.nodeViewModel.id
    }

    @MainActor
    var displayTitle: String {
        self.nodeViewModel.displayTitle
    }

    @MainActor
    var isSelected: Bool {
        canvasViewModel.isSelected
    }

    var body: some View {
        NodeView(graph: graph,
                 node: nodeViewModel,
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
                           node: nodeViewModel,
                           nodeIO: .input,
                           isNodeSelected: isSelected,
                           adjustmentBarSessionId: adjustmentBarSessionId)
    }

    @ViewBuilder @MainActor
    func outputsViews() -> some View {
        DefaultNodeRowView(graph: graph,
                           node: nodeViewModel,
                           nodeIO: .output,
                           isNodeSelected: isSelected,
                           adjustmentBarSessionId: adjustmentBarSessionId)
    }
}
