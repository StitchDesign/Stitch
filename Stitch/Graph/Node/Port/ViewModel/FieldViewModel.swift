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

protocol FieldViewModel: AnyObject, Identifiable {
    associatedtype PortId = PortViewData
    
    var fieldValue: FieldValue { get set }

    var coordinate: PortId { get set }

    // A port has 1 to many relationship with fields
    var fieldIndex: Int { get set }

    // eg "X" vs "Y" vs "Z" for .point3D parent-value
    // eg "X" vs "Y" for .position parent-value
    var fieldLabel: String { get set }
    
    init(fieldValue: FieldValue,
         coordinate: PortId,
         fieldIndex: Int,
         fieldLabel: String)
}

final class InputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var coordinate: InputPortViewData
    var fieldIndex: Int
    var fieldLabel: String
    
    init(fieldValue: FieldValue,
         coordinate: InputPortViewData,
         fieldIndex: Int,
         fieldLabel: String) {
        self.fieldValue = fieldValue
        self.coordinate = coordinate
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
    }
}

final class OutputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var coordinate: OutputPortViewData
    var fieldIndex: Int
    var fieldLabel: String
    
    init(fieldValue: FieldValue,
         coordinate: OutputPortViewData,
         fieldIndex: Int,
         fieldLabel: String) {
        self.fieldValue = fieldValue
        self.coordinate = coordinate
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
    }
}

extension InputFieldViewModel {
    var id: FieldCoordinate { .init(input: self.coordinate,
                                    fieldIndex: self.fieldIndex) }
}

extension Array where Element: FieldViewModel {
    init(_ fieldGroupType: FieldGroupType,
         coordinate: Element.PortId,
         startingFieldIndex: Int) {
        let labels = fieldGroupType.labels
        let defaultValues = fieldGroupType.defaultFieldValues

        self = defaultValues.enumerated().map { index, fieldValue in
            let fieldLabel = labels[safe: index] ?? ""

            return .init(fieldValue: fieldValue,
                         coordinate: coordinate,
                         fieldIndex: startingFieldIndex + index,
                         fieldLabel: fieldLabel)
        }
    }
}
