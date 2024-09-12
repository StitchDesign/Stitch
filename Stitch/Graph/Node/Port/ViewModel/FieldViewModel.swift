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

protocol FieldViewModel: AnyObject, Observable, Identifiable {
    associatedtype NodeRowType: NodeRowViewModel
    
    var fieldValue: FieldValue { get set }

    // A port has 1 to many relationship with fields
    var fieldIndex: Int { get set }

    // eg "X" vs "Y" vs "Z" for .point3D parent-value
    // eg "X" vs "Y" for .position parent-value
    var fieldLabel: String { get set }

    // e.g. Layer's size-scenario is "Constrain Height",
    // so we "block out" the Height fields on the Layer: size.height, minSize.height, maxSize.height
    var isBlockedOut: Bool { get set }
    
    var rowViewModelDelegate: NodeRowType? { get set }
    
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: NodeRowType?)
}

@Observable
final class InputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var fieldIndex: Int
    var fieldLabel: String
    var isBlockedOut: Bool = false

    weak var rowViewModelDelegate: InputNodeRowViewModel?
    
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: InputNodeRowViewModel?) {
        self.fieldValue = fieldValue
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

@Observable
final class OutputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var fieldIndex: Int
    var fieldLabel: String
    var isBlockedOut: Bool = false
    
    weak var rowViewModelDelegate: OutputNodeRowViewModel?
    
    init(fieldValue: FieldValue,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: OutputNodeRowViewModel?) {
        self.fieldValue = fieldValue
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

extension FieldViewModel {
    var id: FieldCoordinate {
        return .init(rowId: self.rowViewModelDelegate?.id ?? .empty,
                     fieldIndex: self.fieldIndex)
    }
    
    var rowDelegate: Self.NodeRowType.RowObserver? {
        self.rowViewModelDelegate?.rowDelegate
    }
}


// i.e. `createFieldObservers`
// We can't rely on the underlying data anymore;
extension Array where Element: FieldViewModel {
    init(_ fieldGroupType: FieldGroupType,

         // Unpacked ports need special logic for grabbing their proper label
         // e.g. the `y-field` of an unpacked `Position` layer input would otherwise have a field group type of `number` and a field index of 0, resulting in no label at all
         unpackedPortParentFieldGroupType: FieldGroupType?,
         unpackedPortIndex: Int?,
         
         startingFieldIndex: Int,
//         fieldIndex: Int,
         rowViewModel: Element.NodeRowType?) {
        
        let fieldGroup = unpackedPortParentFieldGroupType ?? fieldGroupType
        
        let labels = fieldGroupType.labels
        let defaultValues = fieldGroupType.defaultFieldValues

        
        // we can no longer just assume enumeration
//        self = defaultValues.enumerated().map { index, fieldValue in
        
        self = defaultValues.enumerated().map { fieldIndex, fieldValue in
            
            let index = unpackedPortIndex ?? fieldIndex
        
//        self = defaultValues.map { fieldValue in
//            let fieldLabel = labels[safe: index] ?? ""
            
            // what probably happens is that we have an unpacked "port" for a Position layer property,
            
            let _fieldlabel = labels[safe: index]
//            let _fieldlabel = labels[safe: fieldIndex]
            // Every field should have a label, even if just an empty string
//            if _fieldlabel == nil {
//                fatalErrorIfDebug()
//            }
//            
//            let fieldLabel = _fieldlabel ?? ""
            let fieldLabel = _fieldlabel ?? "NO LABEL"
            
            // We actually ARE finding the label, but there's no field label for e.g. just the Unpacked number type in a

            return .init(fieldValue: fieldValue,
                         fieldIndex: startingFieldIndex + index,
//                         fieldIndex: startingFieldIndex + fieldIndex,
                         fieldLabel: fieldLabel,
                         rowViewModelDelegate: rowViewModel)
        }
    }
}
