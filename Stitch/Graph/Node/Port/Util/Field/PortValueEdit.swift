//
//  PortValueEdit.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/3/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension PortValue {

    // "Is this PortValue editable via a text field?"
    // (Previously was any kind of edit, even via dropdown.)
    var isEditable: Bool {
        switch self {
        case .pulse,
             .color,
             .none,
             .asyncMedia,
             .transform,
             .shape:
            // add?: .importAction
            return false
        default:
            // ie can edit .position, .point3D, .string etc.
            // via a text field.
            return true
        }
    }

    // Some PortValues (.anchoring, .point3D, .bool etc.)
    // are never edited via direct text input.
    // Instead, they use a drop-down,
    // or aren't editable at all.

    // TODO: get rid of this or combine with `isEditable`?
    var isDirectlyEditable: Bool {
        if !self.isEditable {
            return false
        }

        switch self {
        case
            // uses adjustment bar
            .color,

            // uses a button
            .bool,

            // multifield values edited via
            // separate number/layerDimension fields
            .position, .size, .point3D,

            // not editable
            .pulse, .none, .transform,

            // chosen via file import, not text edit
            .asyncMedia,

            // drop-down selection
            .anchoring, .scrollMode, .plane,
            .textAlignment, .textVerticalAlignment:
            //            log("isDirectlyEditable: false")
            return false
        default:
            //            log("isDirectlyEditable: true")
            return true
        }
    }
}
