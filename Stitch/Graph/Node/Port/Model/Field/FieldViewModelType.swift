//
//  FieldViewModelType.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

typealias FieldViewModelTypes = [FieldViewModelType]

enum FieldViewModelType {
    case single(FieldViewModel)
    case multiple(FieldViewModels, String? = nil)
}

extension FieldViewModelType: Identifiable {
    var id: FieldCoordinate {
        switch self {
        case .single(let fieldViewModel):
            return fieldViewModel.id
        case .multiple(let fieldViewModels, _):
            return fieldViewModels.first!.id
        }
    }
}

extension FieldViewModelType {
    var viewModels: FieldViewModels {
        switch self {
        case .single(let fieldViewModel):
            return [fieldViewModel]
        case .multiple(let fieldViewModels, _):
            return fieldViewModels
        }
    }
}

extension FieldViewModelTypes {
    init(singleFieldValue: FieldValue,
         coordinate: NodeIOCoordinate,
         fieldLabel: String = "") {
        self = [
            .single(
                FieldViewModel(fieldValue: singleFieldValue,
                               coordinate: coordinate,
                               fieldIndex: 0,
                               fieldLabel: fieldLabel)
            )
        ]
    }
}
