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

    var id: NodeIOPortType { get set }

    // A port has 1 to many relationship with fields
    var fieldIndex: Int { get set }

    // eg "X" vs "Y" vs "Z" for .point3D parent-value
    // eg "X" vs "Y" for .position parent-value
    var fieldLabel: String { get set }
    
    var rowViewModelDelegate: NodeRowType? { get set }
    
    init(fieldValue: FieldValue,
         id: NodeIOPortType,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: NodeRowType?)
}

final class InputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var id: NodeIOPortType
    var fieldIndex: Int
    var fieldLabel: String
    weak var rowViewModelDelegate: InputNodeRowViewModel?
    
    init(fieldValue: FieldValue,
         id: NodeIOPortType,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: InputNodeRowViewModel?) {
        self.fieldValue = fieldValue
        self.id = id
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

final class OutputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var id: NodeIOPortType
    var fieldIndex: Int
    var fieldLabel: String
    weak var rowViewModelDelegate: OutputNodeRowViewModel?
    
    init(fieldValue: FieldValue,
         id: NodeIOPortType,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: OutputNodeRowViewModel?) {
        self.fieldValue = fieldValue
        self.id = id
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

extension FieldViewModel {
    var id: FieldCoordinate {
        guard let nodeId = self.rowViewModelDelegate?.nodeDelegate?.id else {
            fatalErrorIfDebug()
            return .fakeFieldCoordinate
        }
        
        return .init(rowId: self.id,
                     nodeId: nodeId,
                     fieldIndex: self.fieldIndex)
    }
    
    var rowDelegate: Self.NodeRowType.RowObserver? {
        self.rowViewModelDelegate?.rowDelegate
    }
}

extension Array where Element: FieldViewModel {
    init(_ fieldGroupType: FieldGroupType,
         id: NodeIOPortType,
         startingFieldIndex: Int,
         rowViewModel: Element.NodeRowType?) {
        let labels = fieldGroupType.labels
        let defaultValues = fieldGroupType.defaultFieldValues

        self = defaultValues.enumerated().map { index, fieldValue in
            let fieldLabel = labels[safe: index] ?? ""

            return .init(fieldValue: fieldValue,
                         id: id,
                         fieldIndex: startingFieldIndex + index,
                         fieldLabel: fieldLabel,
                         rowViewModelDelegate: rowViewModel)
        }
    }
}
