//
//  FieldCoordinate.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit

struct FieldCoordinate: Hashable {
    // the index where this field belongs
    var rowId: NodeRowViewModelId

    // the particular field in the
    // 0 for single-field inputs
    var fieldIndex: Int

    static let fakeFieldCoordinate: Self = .init(
            rowId: .init(graphItemType: .canvas(.node(.init())),
                         nodeId: .init(),
                         portId: 0),
            fieldIndex: 0)
}
