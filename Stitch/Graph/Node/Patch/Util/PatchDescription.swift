//
//  PatchDescription.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/23.
//

import Foundation
import StitchSchemaKit

extension Patch {

    var nodeDescription: String {
        // Add new line
        "\n\(self.nodeDescriptionBody)"
    }

    var nodeDescriptionBody: String {
        NodeDescriptions.forKind(.patch(self))!
    }
}
