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
        ForEach(fieldGroupViewModel.fieldObservers) { (fieldViewModel: FieldType) in
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
                self.valueEntryView(fieldViewModel, isMultiField)
            }
        }
        .allowsHitTesting(!isForPropertyAlreadyOnGraph)
    }
}
