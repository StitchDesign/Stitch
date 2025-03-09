//
//  NodeFieldsView.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 5/30/23.
//

import SwiftUI
import StitchSchemaKit


typealias LayerPortTypeSet = Set<LayerInputKeyPathType>

struct NodeFieldsView<FieldType, ValueEntryView, FieldsView>: View where FieldType: FieldViewModel,
                                                             ValueEntryView: View,
                                                             FieldsView: View {
    let fieldGroupViewModel: FieldGroupTypeData<FieldType>
    
    @ViewBuilder var valueEntryView: (FieldType, Bool) -> ValueEntryView
    @ViewBuilder var fieldsView: () -> FieldsView
    
    var layerInput: LayerInputPort? {
        fieldGroupViewModel.layerInput
    }
    
    var body: some View {
        
        // Only non-nil for 3D transform
        // NOTE: this only shows up for PACKED 3D Transform; unpacked 3D Transform fields are treat as Number fields, which are not created with a `groupLabel`
        // Alternatively we could create Number fieldGroups with their proper parent label if they are for an unpacked multifeld layer input?
        if let fieldGroupLabel = fieldGroupViewModel.groupLabel {
            HStack {
                LabelDisplayView(label: fieldGroupLabel,
                                 isLeftAligned: false,
                                 fontColor: STITCH_FONT_GRAY_COLOR,
                                 isSelectedInspectorRow: false)
                Spacer()
            }
        }
        
        fieldsView()
    }
}


struct NodePortContrainedFieldsView<FieldType, ValueEntryView>: View where FieldType: FieldViewModel, ValueEntryView: View {
    let fieldGroupViewModel: FieldGroupTypeData<FieldType>
    let isMultiField: Bool
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
    
    var body: some View {
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
        
        // See note in `NodeInputView`: this use assumes Margin and Padding are in a Packed state, i.e. one row observer and 4 field models
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
