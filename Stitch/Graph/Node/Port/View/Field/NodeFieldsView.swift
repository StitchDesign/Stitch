//
//  NodeFieldsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/30/23.
//

import SwiftUI
import StitchSchemaKit

struct NodeFieldsView<FieldType, ValueEntryView>: View where FieldType: FieldViewModel,
                                                             ValueEntryView: View {
    @Bindable var graph: GraphState
    @Bindable var fieldGroupViewModel: FieldGroupTypeViewModel<FieldType>
    let nodeId: NodeId
    let isGroupNodeKind: Bool
    let isMultiField: Bool
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool
    @ViewBuilder var valueEntryView: (FieldType, Bool) -> ValueEntryView

    var label: String? {
        // if this is an input or output on a splitter node for a group node,
        // then use the splitter node's title directly:
           if isGroupNodeKind {
               if let nodeVM = graph.getNodeViewModel(nodeId) {
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
    
    var isForPropertyAlreadyOnGraph: Bool {
        forPropertySidebar && propertyIsAlreadyOnGraph
    }
    
    var body: some View {
        if let groupLabel = label {
            StitchTextView(string: groupLabel)
        }

        ForEach(fieldGroupViewModel.fieldObservers) { (fieldViewModel: FieldType) in
            self.valueEntryView(fieldViewModel, isMultiField)
        }
        .allowsHitTesting(!isForPropertyAlreadyOnGraph)
    }

//    @ViewBuilder
//    func valueEntryView(_ viewModel: FieldType) -> ValueEntry {
//        ValueEntry(graph: graph,
//                   rowObserver: rowObserver,
//                   viewModel: viewModel,
//                   fieldCoordinate: .init(input: coordinate, fieldIndex: viewModel.fieldIndex),
//                   nodeIO: nodeIO,
//                   isMultiField: isMultiField,
//                   nodeKind: nodeKind,
//                   isCanvasItemSelected: isCanvasItemSelected,
//                   hasIncomingEdge: hasIncomingEdge,
//                   adjustmentBarSessionId: adjustmentBarSessionId,
//                   forPropertySidebar: forPropertySidebar,
//                   propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
//    }
}
