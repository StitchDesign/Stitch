//
//  FieldCoordinate.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit

struct FieldCoordinate: Hashable {
    // the input index where this field belongs
    var portId: Int
    
    // the canvas item where this resides
    var canvasId: CanvasItemId

    // the particular field in the
    // 0 for single-field inputs
    var fieldIndex: Int

    static var fakeFieldCoordinate: Self {
        .init(
            portData: .init(portId: 0, canvasId: .node(.init())),
            fieldIndex: 0)
    }
}
