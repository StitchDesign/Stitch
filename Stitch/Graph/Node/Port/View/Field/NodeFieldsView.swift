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
    let isCanvasItemSelected: Bool
    let hasIncomingEdge: Bool
    let adjustmentBarSessionId: AdjustmentBarSessionId
    let forPropertySidebar: Bool
    let propertyIsAlreadyOnGraph: Bool

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
    
    var isForPropertyAlreadyOnGraph: Bool {
        forPropertySidebar && propertyIsAlreadyOnGraph
    }
    
    var body: some View {
        
        if allFieldsBlockedOut {
            EmptyView()
        } else {
            
            // Only non-nil for ShapeCommands i.e. `lineTo`, `curveTo` etc. ?
            if let groupLabel = label {
                StitchTextView(string: groupLabel)
            }
            
            fieldsStack
        }
    }
    
    @ViewBuilder
    var fieldsStack: some View {
        if forPropertySidebar {
            VStack {
                fields
            }
        } else {
            fields
        }
    }
    
    var allFieldsBlockedOut: Bool {
        fieldGroupViewModel.fieldObservers.allSatisfy(\.isBlockedOut)
    }
        
    var fields: some View {
        ForEach(fieldGroupViewModel.fieldObservers) { (fieldViewModel: FieldViewModel) in
//            self.valueEntryView(fieldViewModel)
//                .overlay {
//                    if fieldViewModel.isBlockedOut {
//                        Color.black.opacity(0.3)
//                            .cornerRadius(4)
//                            .allowsHitTesting(false)
//                    } else {
//                        Color.clear
//                    }
//                }
            
            if !fieldViewModel.isBlockedOut {
                self.valueEntryView(fieldViewModel)
            }
        }
        .allowsHitTesting(!isForPropertyAlreadyOnGraph)
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
                   isCanvasItemSelected: isCanvasItemSelected,
                   hasIncomingEdge: hasIncomingEdge,
                   adjustmentBarSessionId: adjustmentBarSessionId,
                   forPropertySidebar: forPropertySidebar,
                   propertyIsAlreadyOnGraph: propertyIsAlreadyOnGraph)
    }
}
