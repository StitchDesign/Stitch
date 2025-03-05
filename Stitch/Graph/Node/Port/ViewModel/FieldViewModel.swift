//
//  FieldViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

typealias InputFieldViewModels = [InputFieldViewModel]
typealias OutputFieldViewModels = [OutputFieldViewModel]

protocol FieldViewModel: StitchLayoutCachable, Observable, AnyObject, Identifiable where Self.ID == FieldCoordinate {
    associatedtype NodeRowType: NodeRowViewModel
    
    @MainActor var fieldValue: FieldValue { get set }

    // A port has 1 to many relationship with fields
    @MainActor var fieldIndex: Int { get set }

    // eg "X" vs "Y" vs "Z" for .point3D parent-value
    // eg "X" vs "Y" for .position parent-value
    @MainActor var fieldLabel: String { get set }
    
    @MainActor var rowViewModelDelegate: NodeRowType? { get set }
    
    @MainActor
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: NodeRowType?)
}

extension FieldViewModel {
    
    // a field index that ignores packed vs. unpacked mode
    // so e.g. a field view model for a height field of a size input will have a fieldLabelIndex of 1, not 0
    @MainActor
    var fieldLabelIndex: Int {
        guard let rowViewModelDelegate = rowViewModelDelegate else {
            fatalErrorIfDebug()
            return fieldIndex
        }

        switch rowViewModelDelegate.id.portType {

        case .portIndex:
            // leverage patch node definition to get label
            return fieldIndex

        case .keyPath(let layerInputType):

            switch layerInputType.portType {
            case .packed:
                // if it is packed, then field index is correct,
                // so can use proper label list etc.
                return fieldIndex

            case .unpacked(let unpackedPortType):
                let index = unpackedPortType.rawValue
                return index
            }
        }
    }
}

@Observable
final class InputFieldViewModel: FieldViewModel {
    let id: FieldCoordinate
    @MainActor var fieldValue: FieldValue
    @MainActor var fieldIndex: Int
    @MainActor var fieldLabel: String
    @MainActor var viewCache: NodeLayoutCache?

    @MainActor weak var rowViewModelDelegate: InputNodeRowViewModel?
    
    @MainActor
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: InputNodeRowViewModel?) {
        self.id = .init(rowId: rowViewModelDelegate?.id ?? .empty,
                        fieldIndex: fieldIndex)
        self.fieldValue = fieldValue
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

@Observable
final class OutputFieldViewModel: FieldViewModel {
    let id: FieldCoordinate
    @MainActor var fieldValue: FieldValue
    @MainActor var fieldIndex: Int
    @MainActor var fieldLabel: String
    @MainActor var viewCache: NodeLayoutCache?
    
    @MainActor weak var rowViewModelDelegate: OutputNodeRowViewModel?
    
    @MainActor
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: OutputNodeRowViewModel?) {
        self.id = .init(rowId: rowViewModelDelegate?.id ?? .empty,
                        fieldIndex: fieldIndex)
        self.fieldValue = fieldValue
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

extension FieldViewModel {
    @MainActor
    var rowDelegate: Self.NodeRowType.RowObserver? {
        self.rowViewModelDelegate?.rowDelegate
    }
}


// i.e. `createFieldObservers`
extension Array where Element: FieldViewModel {
    
    // Easier to find via XCode search
    @MainActor
    static func createFieldViewModels(fieldValues: FieldValues,
                                      fieldGroupType: FieldGroupType,
                                      // Unpacked ports need special logic for grabbing their proper label
                                      // e.g. the `y-field` of an unpacked `Position` layer input would otherwise have a field group type of `number` and a field index of 0, resulting in no label at all
                                      unpackedPortParentFieldGroupType: FieldGroupType?,
                                      unpackedPortIndex: Int?,
                                      startingFieldIndex: Int,
                                      rowViewModel: Element.NodeRowType?) -> Array<Element> {
        
        assertInDebug(!fieldValues.isEmpty)
        
        // If this is a field for an unpacked layer input, we must look at the unpacked's parent label-list
        let labels = (unpackedPortParentFieldGroupType ?? fieldGroupType).labels
        let layerInput = rowViewModel?.rowDelegate?.id.layerInput?.layerInput
                
        return fieldValues.enumerated().map { fieldIndex, fieldValue in
            
            let index = unpackedPortIndex ?? fieldIndex
            let indexForLabel = self.getIndexForLabel(index: index,
                                                      layerInput: layerInput)
                
            let fieldLabel = labels[safe: indexForLabel]
            
            // Every field should have a label, even if just an empty string.
            assertInDebug(fieldLabel != nil)
            
            return Element(fieldValue: fieldValue,
                           fieldIndex: startingFieldIndex + index,
                           fieldLabel: fieldLabel ?? "",
                           rowViewModelDelegate: rowViewModel)
        }
    }
    
    private static func getIndexForLabel(index: Int,
                                         layerInput: LayerInputPort?) -> Int {
        guard let labelGropuings = layerInput?.labelGroupings else {
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
