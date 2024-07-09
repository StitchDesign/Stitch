//
//  FieldViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

typealias FieldViewModels = [FieldViewModel]

@Observable
class FieldViewModel {
    var fieldValue: FieldValue

    let coordinate: NodeIOCoordinate

    // A port has 1 to many relationship with fields
    let fieldIndex: Int

    // eg "X" vs "Y" vs "Z" for .point3D parent-value
    // eg "X" vs "Y" for .position parent-value
    var fieldLabel: String

    // e.g. Layer's size-scenario is "Constrain Height",
    // so we "block out" the Height fields on the Layer: size.height, minSize.height, maxSize.height
    var isBlockedOut: Bool = false
    
    init(fieldValue: FieldValue,
         coordinate: NodeIOCoordinate,
         fieldIndex: Int,
         fieldLabel: String) {

        self.fieldValue = fieldValue
        self.coordinate = coordinate
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
    }
}

extension FieldViewModel: Identifiable {
    var id: FieldCoordinate { .init(input: self.coordinate,
                                    fieldIndex: self.fieldIndex) }
}

extension FieldViewModels {
    init(_ fieldGroupType: FieldGroupType,
         coordinate: NodeIOCoordinate,
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
