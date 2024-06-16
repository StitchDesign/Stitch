//
//  NodeFieldsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/30/23.
//

import SwiftUI
import StitchSchemaKit

struct NodeFieldsView: View {
    @Bindable var graph: GraphState
    @Bindable var rowObserver: NodeRowObserver
    @ObservedObject var fieldGroupViewModel: FieldGroupTypeViewModel
    let coordinate: NodeIOCoordinate
    let nodeKind: NodeKind
    let nodeIO: NodeIO
    let isNodeSelected: Bool
    let hasIncomingEdge: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId

    var isMultiField: Bool {
        self.fieldGroupViewModel.fieldObservers.count > 1
    }

    var label: String? {
        // if this is an input or output on a splitter node for a group node,
        // then use the splitter node's title directly:
           if nodeKind == .group {
               if let nodeVM = graph.getNodeViewModel(coordinate.nodeId) {
                   @Bindable var nodeViewModel = nodeVM
                   let title = nodeViewModel.title
                   // Don't use label if group splitter does not have custom title
                   return title == Patch.splitter.defaultDisplayTitle() ? "" : title
               } else {
                   #if DEBUG || DEV_DEBUG
                   return "NO LABEL"
                   #endif
                   return ""
               }
           } else {
               return fieldGroupViewModel.groupLabel
           }
       }
    
    var body: some View {
        if let groupLabel = label {
            StitchTextView(string: groupLabel)
        }

        ForEach(fieldGroupViewModel.fieldObservers) { (fieldViewModel: FieldViewModel) in
            self.valueEntryView(fieldViewModel)
        }
    }

    @ViewBuilder
    func valueEntryView(_ viewModel: FieldViewModel) -> ValueEntry {
        ValueEntry(graph: graph,
                   rowObserver: rowObserver,
                   viewModel: viewModel,
                   fieldCoordinate: .init(input: coordinate, fieldIndex: viewModel.fieldIndex),
                   nodeIO: nodeIO,
                   isMultiField: isMultiField,
                   nodeKind: nodeKind,
                   isNodeSelected: isNodeSelected,
                   hasIncomingEdge: hasIncomingEdge,
                   adjustmentBarSessionId: adjustmentBarSessionId)
    }
}
