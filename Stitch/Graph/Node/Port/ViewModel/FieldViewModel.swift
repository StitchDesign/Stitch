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
    associatedtype PortId: PortViewData
    associatedtype NodeRowType: NodeRowViewModel
    
    var fieldValue: FieldValue { get set }

    var coordinate: PortId { get set }

    // A port has 1 to many relationship with fields
    var fieldIndex: Int { get set }

    // eg "X" vs "Y" vs "Z" for .point3D parent-value
    // eg "X" vs "Y" for .position parent-value
    var fieldLabel: String { get set }
    
    var rowViewModelDelegate: NodeRowType? { get }
    
    init(fieldValue: FieldValue,
         coordinate: PortId,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: NodeRowType)
}

final class InputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var coordinate: InputPortViewData
    var fieldIndex: Int
    var fieldLabel: String
    weak var rowViewModelDelegate: InputNodeRowViewModel?
    
    init(fieldValue: FieldValue,
         coordinate: InputPortViewData,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: InputNodeRowViewModel) {
        self.fieldValue = fieldValue
        self.coordinate = coordinate
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

final class OutputFieldViewModel: FieldViewModel {
    var fieldValue: FieldValue
    var coordinate: OutputPortViewData
    var fieldIndex: Int
    var fieldLabel: String
    weak var rowViewModelDelegate: OutputNodeRowViewModel?
    
    init(fieldValue: FieldValue,
         coordinate: OutputPortViewData,
         fieldIndex: Int,
         fieldLabel: String,
         rowViewModelDelegate: OutputNodeRowViewModel) {
        self.fieldValue = fieldValue
        self.coordinate = coordinate
        self.fieldIndex = fieldIndex
        self.fieldLabel = fieldLabel
        self.rowViewModelDelegate = rowViewModelDelegate
    }
}

extension FieldViewModel {
    var id: FieldCoordinate {
        .init(portId: self.coordinate.portId,
              canvasId: self.coordinate.canvasId,
              fieldIndex: self.fieldIndex)
    }
}

extension Array where Element: FieldViewModel {
    init(_ fieldGroupType: FieldGroupType,
         coordinate: Element.PortId,
         startingFieldIndex: Int,
         rowViewModel: Element.NodeRowType) {
        let labels = fieldGroupType.labels
        let defaultValues = fieldGroupType.defaultFieldValues

        self = defaultValues.enumerated().map { index, fieldValue in
            let fieldLabel = labels[safe: index] ?? ""

            return .init(fieldValue: fieldValue,
                         coordinate: coordinate,
                         fieldIndex: startingFieldIndex + index,
                         fieldLabel: fieldLabel,
                         rowViewModelDelegate: rowViewModel)
        }
    }
}
