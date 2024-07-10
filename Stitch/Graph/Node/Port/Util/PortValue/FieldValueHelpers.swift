//
//  ParentPortValue.swift
//  prototype
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let SIZE_FIELD_HEIGHT_LABEL = "H"
let SIZE_FIELD_WIDTH_LABEL = "W"

let POSITION_FIELD_Y_LABEL = "Y"
let POSITION_FIELD_X_LABEL = "X"

extension LayerSize {
    var fieldValues: FieldValues {
        [.layerDimension(self.width.fieldValue), .layerDimension(self.height.fieldValue)]
    }
}

extension StitchPosition {
    var fieldValues: FieldValues {
        [.number(Double(self.width)), .number(Double(self.height))]
    }
}

extension Point3D {
    var fieldValues: FieldValues {
        [.number(self.x), .number(self.y), .number(self.z)]
    }
}

extension Point4D {
    var fieldValues: FieldValues {
        [.number(self.x), .number(self.y), .number(self.z), .number(self.w)]
    }
}

extension StitchPadding {
    var fieldValues: FieldValues {
        [
            .number(self.top),
            .number(self.right),
            .number(self.bottom),
            .number(self.left)
        ]
    }
}
