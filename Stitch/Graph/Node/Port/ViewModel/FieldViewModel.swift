//
//  FieldViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

typealias InputFieldViewModel = FieldViewModel
typealias OutputFieldViewModel = FieldViewModel

typealias InputFieldViewModels = [InputFieldViewModel]
typealias OutputFieldViewModels = [OutputFieldViewModel]

@Observable
final class FieldViewModel: Observable, AnyObject, Identifiable, Sendable {
    
    let id: FieldCoordinate
    @MainActor var fieldValue: FieldValue
    
    @MainActor var fieldLabel: String
    
    @MainActor var fieldIndex: Int {
        self.fieldIndexWhichIgnoresPackedVsUnpacked()
    }
    
    @MainActor private var _fieldIndex: Int
    
    @MainActor
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowId: NodeRowViewModelId) {
        self.id = FieldCoordinate(rowId: rowId, fieldIndex: fieldIndex)
        self.fieldValue = fieldValue
        self._fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
    }
    
    // a field index that ignores packed vs. unpacked mode
    // so e.g. a field view model for a height field of a size input will have a fieldLabelIndex of 1, not 0
    @MainActor
    private func fieldIndexWhichIgnoresPackedVsUnpacked() -> Int {
        
        let portType = self.id.rowId.portType
        
        switch portType {
            
        case .portIndex: // i.e. patch input, patch output, layer output
            return self._fieldIndex

        case .keyPath(let layerInputType):

            switch layerInputType.portType {
            case .packed:
                // if it is packed, then field index is correct,
                // so can use proper label list etc.
                return self._fieldIndex

            case .unpacked(let unpackedPortType):
                return unpackedPortType.rawValue // rawValue = index
            }
        }
    }
}


extension [FieldViewModel] {
    // Easier to find via XCode search
    @MainActor
    static func createFieldViewModels(fieldValues: FieldValues,
                                      fieldGroupType: FieldGroupType,
                                      // Unpacked ports need special logic for grabbing their proper label
                                      // e.g. the `y-field` of an unpacked `Position` layer input would otherwise have a field group type of `number` and a field index of 0, resulting in no label at all
                                      unpackedPortParentFieldGroupType: FieldGroupType?,
                                      unpackedPortIndex: Int?,
                                      startingFieldIndex: Int,
                                      layerInput: LayerInputPort?,
                                      rowId: NodeRowViewModelId) -> [FieldViewModel] {
        
        assertInDebug(!fieldValues.isEmpty)
        
        // TODO: derive this at the UI level ?
        // If this is a field for an unpacked layer input, we must look at the unpacked's parent label-list
        let labels = (unpackedPortParentFieldGroupType ?? fieldGroupType).labels
                
        return fieldValues.enumerated().map { fieldIndex, fieldValue in
            
            let index = unpackedPortIndex ?? fieldIndex
            let indexForLabel = self.getIndexForLabel(index: index,
                                                      layerInput: layerInput)
                
            let fieldLabel = labels[safe: indexForLabel]
            
            // Every field should have a label, even if just an empty string.
            assertInDebug(fieldLabel != nil)
            
            return FieldViewModel(fieldValue: fieldValue,
                                  fieldIndex: startingFieldIndex + index,
                                  fieldLabel: fieldLabel ?? "",
                                  rowId: rowId)
        }
    }
    
    private static func getIndexForLabel(index: Int,
                                         layerInput: LayerInputPort?) -> Int {
        guard let labelGropuings = layerInput?.transform3DLabelGroupings else {
            // Almsot all cases (non 3D transform)
            return index
        }
        
        // Find label where index is in range
        for grouping in labelGropuings {
            if grouping.portRange.contains(index) {
                let indexInRange = index - grouping.portRange.startIndex
                return indexInRange
            }
        }
        
        // Should've found match
        fatalErrorIfDebug()
        return 0
    }
}
