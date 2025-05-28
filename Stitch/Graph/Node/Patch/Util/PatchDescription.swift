//
//  PatchDescription.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/12/23.
//

import Foundation
import StitchSchemaKit

extension Patch {

    var nodeDescription: String? {
        guard let description = self.nodeDescriptionBody else {
            return nil
        }
        
        // Add new line
        return "\n\(description)"
    }

    var nodeDescriptionBody: String? {
        StitchDocsRouter.patch(.patch(self)).description
    }
}
