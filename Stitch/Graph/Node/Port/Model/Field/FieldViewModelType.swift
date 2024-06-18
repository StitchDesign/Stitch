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
    case single(InputFieldViewModel)
    case multiple([InputFieldViewModel], String? = nil)
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
    var viewModels: [InputFieldViewModel] {
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
         fieldLabel: String = "",
         rowViewModelDelegate: InputNodeRowViewModel) {
        self = [
            .single(
                InputFieldViewModel(fieldValue: singleFieldValue,
                                    fieldIndex: 0,
                                    fieldLabel: fieldLabel,
                                    rowViewModelDelegate: rowViewModelDelegate)
            )
        ]
    }
}
