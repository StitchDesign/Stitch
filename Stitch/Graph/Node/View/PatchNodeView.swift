//
//  PatchNodeView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/11/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct PatchNodeView: View {
    @Bindable var graph: GraphState
    @Bindable var viewModel: NodeViewModel
    @Bindable var patchNode: PatchNodeViewModel

    let atleastOneCommentBoxSelected: Bool
    let activeGroupId: GroupNodeId?
    let activeIndex: ActiveIndex

    let boundsReaderDisabled: Bool
    let usePositionHandler: Bool
    let updateMenuActiveSelectionBounds: Bool
    let isHiddenDuringAnimation: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId

    // Use state rather than computed variable due to perf cost
    @State private var sortedUserTypeChoices = [UserVisibleType]()

    var id: NodeId {
        self.viewModel.id
    }

    var nodeUIKind: NodeUIKind {
        self.patch.nodeUIKind
    }

    var patch: Patch {
        self.patchNode.patch
    }

    var userVisibleType: UserVisibleType? {
        self.patchNode.userVisibleType
    }

    var userTypeChoices: Set<UserVisibleType> {
        self.patch.availableNodeTypes
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
                 canAddInput: viewModel.canAddInputs,
                 canRemoveInput: viewModel.canRemoveInputs,
                 sortedUserTypeChoices: sortedUserTypeChoices,
                 boundsReaderDisabled: boundsReaderDisabled,
                 usePositionHandler: usePositionHandler,
                 updateMenuActiveSelectionBounds: updateMenuActiveSelectionBounds,
                 isHiddenDuringAnimation: isHiddenDuringAnimation,
                 inputsViews: inputsViews,
                 outputsViews: outputsViews)
            .onChange(of: self.patch, initial: true) {
                // Sorting is expensive so we control when this is calculated
                self.sortedUserTypeChoices = self.patchNode.getSortedUserTypeChoices()
            }
    }

    @ViewBuilder @MainActor
    func inputsViews() -> some View {
        VStack(alignment: .leading,
                      spacing: SPACING_BETWEEN_NODE_ROWS) {
            if self.patch == .wirelessReceiver {
                WirelessPortView(isOutput: false, id: id)
                    .padding(.trailing, NODE_BODY_SPACING)
            } else {
                DefaultNodeRowView(graph: graph,
                                   node: viewModel,
                                   nodeIO: .input,
                                   isNodeSelected: isSelected,
                                   adjustmentBarSessionId: adjustmentBarSessionId)
            }
        }
    }

    @ViewBuilder @MainActor
    func outputsViews() -> some View {
        VStack(alignment: .trailing,
               spacing: SPACING_BETWEEN_NODE_ROWS) {

            if self.patch == .wirelessBroadcaster {
                WirelessPortView(isOutput: true, id: id)
                    .padding(.leading, NODE_BODY_SPACING)
            } else {
                DefaultNodeRowView(graph: graph,
                                   node: viewModel,
                                   nodeIO: .output,
                                   isNodeSelected: isSelected,
                                   adjustmentBarSessionId: adjustmentBarSessionId)
            }
        }
    }
}
