//
//  NodeFieldsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/30/23.
//

import SwiftUI
import StitchSchemaKit


typealias LayerPortTypeSet = Set<LayerInputKeyPathType>

struct NodeFieldsView<FieldType, ValueEntryView>: View where FieldType: FieldViewModel,
                                                             ValueEntryView: View {
    @Bindable var graph: GraphState
    
    // just becomes a list of field models
    @Bindable var fieldGroupViewModel: FieldGroupTypeViewModel<FieldType>
        
    let nodeId: NodeId
    let isMultiField: Bool
    let forPropertySidebar: Bool
    
    let blockedFields: Set<LayerInputKeyPathType>?
    
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
        if let blockedFields = blockedFields {
            return fieldGroupViewModel.fieldObservers.allSatisfy {
                $0.isBlocked(blockedFields)
            }
        }
        
        return false
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
                                                
            let isBlocked = self.blockedFields?.blocks(.unpacked(fieldViewModel.fieldLabelIndex.asUnpackedPortType)) ?? false
                        
            if !isBlocked {
                self.valueEntryView(fieldViewModel, isMultiField)
            }
        }
    }
}

extension FieldViewModel {
    
    // TODO: instrument perf here?
    func isBlocked(_ blockedFields: Set<LayerInputKeyPathType>) -> Bool {
        blockedFields.blocks(.unpacked(self.fieldLabelIndex.asUnpackedPortType))
    }
}

extension Set<LayerInputKeyPathType> {
    func blocks(_ portKeypath: LayerInputKeyPathType) -> Bool {
        
        // If the entire input is blocked,
        // then every field is blocked:
        if self.contains(.packed) {
            return true
        }
        
        // Else, field must be specifically blocked
        return self.contains(portKeypath)
    }
}
