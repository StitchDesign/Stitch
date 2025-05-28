//
//  LayerDescription.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/23.
//

import Foundation
import StitchSchemaKit

extension Layer {
    var nodeDescription: String? {
        guard let description = self.nodeDescriptionBody else {
            return nil
        }
        
        // Add new line
        return "\n\(description)"
    }

    var nodeDescriptionBody: String? {
        StitchDocsRouter.layer(.layer(self)).description
    }
}
