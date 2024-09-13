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
    
    // just becomes a list of field models
    @Bindable var fieldGroupViewModel: FieldGroupTypeViewModel<FieldType>
    
    let nodeId: NodeId
    let isMultiField: Bool
    let forPropertySidebar: Bool
    @ViewBuilder var valueEntryView: (FieldType, Bool) -> ValueEntryView
        
    var body: some View {
        if allFieldsBlockedOut {
            EmptyView()
        } else {
            
            // Only non-nil for ShapeCommands i.e. `lineTo`, `curveTo` etc. ?
            if let fieldGroupLabel = fieldGroupViewModel.groupLabel {
                StitchTextView(string: fieldGroupLabel)
            }
            
            // TODO: how to handle the multifield "shadow offset" input in the Shadow Flyout? For now, we stack those fields vertically
            if isMultiField,
               forPropertySidebar,
               fieldGroupViewModel.id.rowId.portType.keyPath?.layerInput == .shadowOffset {
                VStack {
                    fields
                }
            } else {
                fields
            }
        }
    }
    
    var allFieldsBlockedOut: Bool {
        fieldGroupViewModel.fieldObservers.allSatisfy(\.isBlockedOut)
    }
        
    // fieldObservers / field view models remain our bread-and-butter
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
    }
}
