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
    let forFlyout: Bool
    
    let blockedFields: Set<LayerInputKeyPathType>?
    
    @ViewBuilder var valueEntryView: (FieldType, Bool) -> ValueEntryView
    
    var layerInput: LayerInputPort? {
        fieldGroupViewModel.layerInput
    }
    
    var body: some View {
        // Only non-nil for ShapeCommands i.e. `lineTo`, `curveTo` etc. ?
        if let fieldGroupLabel = fieldGroupViewModel.groupLabel {
            StitchTextView(string: fieldGroupLabel)
        }
        
        // TODO: how to handle the multifield "shadow offset" input in the Shadow Flyout? For now, we stack those fields vertically
        if forPropertySidebar,
           forFlyout,
           isMultiField,
           layerInput == .shadowOffset {
            VStack {
                fields
            }
        }
        
        // TODO: need to pass down `forFlyout` here, so that we do not
        else if forPropertySidebar,
                !forFlyout,
                isMultiField,
                (layerInput == .layerPadding || layerInput == .layerMargin),
                let p1 = fieldGroupViewModel.fieldObservers[safe: 0],
                let p2 = fieldGroupViewModel.fieldObservers[safe: 1],
                let p3 = fieldGroupViewModel.fieldObservers[safe: 2],
                let p4 = fieldGroupViewModel.fieldObservers[safe: 3] {
            VStack {
                HStack {
                    // Individual fields for PortValue.padding can never be blocked; only the input as a whole can be blocked
                    self.valueEntryView(p1, isMultiField)
                    self.valueEntryView(p2, isMultiField)
                }
                HStack {
                    self.valueEntryView(p3, isMultiField)
                    self.valueEntryView(p4, isMultiField)
                }
            }
            // TODO: `LayerInspectorPortView`'s `.listRowInsets` should maintain consistent padding between input-rows in the layer inspector, so why is additional padding needed?
            .padding(.vertical, INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2)
        }
        else {
//            NodeLayout(observer: fieldGroupViewModel) {
                fields
//            }
        }
    }
    
    // fieldObservers / field view models remain our bread-and-butter
    var fields: some View {
        
        // By default, this ForEach bubbles up to an HStack that contains it; how
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

            let isBlocked = self.blockedFields.map { fieldViewModel.isBlocked($0) } ?? false
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
