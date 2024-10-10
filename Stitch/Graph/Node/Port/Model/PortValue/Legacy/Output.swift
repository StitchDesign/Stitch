//
//  Output.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import StitchSchemaKit
import CoreData
import SwiftUI

typealias Outputs = NEA<Output>

// MARK: - Output is no longer used except for legacy PatchNode function definitions.
struct Output {
    // replaces `id` and `nodeId` as separate fields
    var coordinate: OutputCoordinate

    // Changeable only eg in the case of a sizeUnpack patch-node
    // whose node-type has changed.
    var label: String?

    var values: PortValues

    init(coordinate: OutputCoordinate,
         label: String? = nil,
         values: PortValues) {
        self.coordinate = coordinate
        self.label = label
        self.values = values
    }
}
