//
//  NodeFieldsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/30/23.
//

import SwiftUI
import StitchSchemaKit

//extension Set<LayerInputKeyPathType> {
//    func asIndicesOfBlockedFields() -> Set<Int> {
//        self.map {
//            
//        }
//    }
//}

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
    
//////    // TODO: OCT 1: pass down from layer input observer
//    var blockedFields: Set<LayerInputKeyPathType> {
//        
//        // Normally only populated for specific inputs; but this would be for ALL
//        .init([
//            .unpacked(.port1) // only height blocked
////            .unpacked(.port0) // only width blocked
////            .packed // both blocked
//        ])
//    }
    
    
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
//        fieldGroupViewModel.fieldObservers.allSatisfy(\.isBlockedOut)
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
            
//            fieldViewModel.rowViewModelDelegate?.inputUsesTextField
                                    
            let isBlocked = self.blockedFields?.blocks(.unpacked(fieldViewModel.fieldLabelIndex.asUnpackedPortType)) ?? false
            
            logInView("NodeFieldsView: self.blockedFields: \(self.blockedFields)")
            logInView("NodeFieldsView: fieldViewModel.fieldLabel: \(fieldViewModel.fieldLabel)")
            logInView("NodeFieldsView: fieldViewModel.fieldIndex: \(fieldViewModel.fieldIndex)")
            logInView("NodeFieldsView: isBlocked: \(isBlocked)")
            
            if !isBlocked {
                self.valueEntryView(fieldViewModel, isMultiField)
            }
        }
    }
}

extension FieldViewModel {
    
    // How often will this run?
    // and how expensive is the type casting?
    // Can you instead pass down this information from the top level,
    // as info that would rarely or hardly change?
    
    // ... could instrument this...
    
    // Mostly
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
        
//        // A field is blocked if its field is specifically blocked,
//        // or its entire input is blocked:
//        let specificFieldBlocked = self.contains(portKeypath)
//        let wholeInputBlocked = self.contains(.packed)
//        
//        return specificFieldBlocked || wholeInputBlocked
    }
}
