//
//  Input.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias Inputs = NEA<Input>

// MARK: - Input is no longer used except for legacy PatchNode and LayerNode function definitions.
struct Input {
    var coordinate: InputCoordinate // replaces `id` and `nodeId` as separate fields

    // Usually not changeable after creation,
    // except for eg size-node nodeType changes.
    var label: String?

    // a given port can have multiple values,
    // because it can have a loop
    var values: PortValues
}
