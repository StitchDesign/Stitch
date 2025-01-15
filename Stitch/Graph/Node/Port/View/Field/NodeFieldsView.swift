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
    let fieldGroupViewModel: FieldGroupTypeData<FieldType>
        
    let nodeId: NodeId
    let isMultiField: Bool
    let forPropertySidebar: Bool
    let forFlyout: Bool
    
    let blockedFields: Set<LayerInputKeyPathType>?
    
    @ViewBuilder var valueEntryView: (FieldType, Bool) -> ValueEntryView
    
    var layerInput: LayerInputPort? {
        fieldGroupViewModel.layerInput
    }
    
    @ViewBuilder
    func valueEntry(_ fieldType: FieldType?) -> some View {
        if let fieldType = fieldType {
            self.valueEntryView(fieldType,
                                self.isMultiField)
        } else {
            EmptyView()
                .onAppear { fatalErrorIfDebug() }
        }
    }
    
    var displaysNarrowMultifields: Bool {
        switch layerInput {
        case .layerPadding, .layerMargin, .transform3D:
            return true
            
        default:
            return false
        }
    }
    
    @ViewBuilder
    var constrainedMultifieldsView: some View {
        let p0 = fieldGroupViewModel.fieldObservers[safe: 0]
        let p1 = fieldGroupViewModel.fieldObservers[safe: 1]
        let p2 = fieldGroupViewModel.fieldObservers[safe: 2]
        let p3 = fieldGroupViewModel.fieldObservers[safe: 3]
        
        // Always xyz
        if self.layerInput == .transform3D {
            HStack {
                self.valueEntry(p0)
                self.valueEntry(p1)
                self.valueEntry(p2)
            }
        }
        
        else if fieldGroupViewModel.fieldObservers.count == 4 {
            VStack {
                HStack {
                    // Individual fields for PortValue.padding can never be blocked; only the input as a whole can be blocked
                    self.valueEntry(p0)
                    self.valueEntry(p1)
                }
                HStack {
                    self.valueEntry(p2)
                    self.valueEntry(p3)
                }
            }
        }
        
        else {
            EmptyView()
                .onAppear {
                    fatalErrorIfDebug()
                }
        }
    }
    
    var body: some View {
        
        // Only non-nil for 3D transform
        // NOTE: this only shows up for PACKED 3D Transform; unpacked 3D Transform fields are treat as Number fields, which are not created with a `groupLabel`
        // Alternatively we could create Number fieldGroups with their proper parent label if they are for an unpacked multifeld layer input?
        if let fieldGroupLabel = fieldGroupViewModel.groupLabel {
            HStack {
//                Spacer()
                StitchTextView(string: fieldGroupLabel)
                Spacer()
            }
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
        
        else if forPropertySidebar,
                !forFlyout,
                isMultiField,
                displaysNarrowMultifields {
            HStack {
                Spacer()
                constrainedMultifieldsView
            }
            // TODO: `LayerInspectorPortView`'s `.listRowInsets` should maintain consistent padding between input-rows in the layer inspector, so why is additional padding needed?
            .padding(.vertical, INSPECTOR_LIST_ROW_TOP_AND_BOTTOM_INSET * 2)
        }
        
        // flyout fields generally are vertically stacked (`shadowOffset` is exception)
        else if forFlyout {
            VStack {
                fields
            }
        }
        
        // patch inputs and inspector fields are horizontally aligned
        else {
            HStack {
                fields
            }
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
    @MainActor
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
