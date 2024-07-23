//
//  FieldCoordinate.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit

struct FieldCoordinate: Equatable, Hashable, Codable {
    // the input where this field belongs
    let input: InputCoordinate

    // the particular field in the
    // 0 for single-field inputs
    var fieldIndex: Int

    static var fakeFieldCoordinate: FieldCoordinate {
        FieldCoordinate(
            input: .fakeInputCoordinate,
            fieldIndex: 0)
    }
}
