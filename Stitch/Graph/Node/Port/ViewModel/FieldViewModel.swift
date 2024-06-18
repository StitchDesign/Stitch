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

extension Array where Element: FieldViewModel {
    init(_ fieldGroupType: FieldGroupType,
         startingFieldIndex: Int,
         rowViewModel: Element.NodeRowType?) {
        let labels = fieldGroupType.labels
        let defaultValues = fieldGroupType.defaultFieldValues

        self = defaultValues.enumerated().map { index, fieldValue in
            let fieldLabel = labels[safe: index] ?? ""

            return .init(fieldValue: fieldValue,
                         fieldIndex: startingFieldIndex + index,
                         fieldLabel: fieldLabel,
                         rowViewModelDelegate: rowViewModel)
        }
    }
}
