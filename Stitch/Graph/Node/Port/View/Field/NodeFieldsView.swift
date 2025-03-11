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
