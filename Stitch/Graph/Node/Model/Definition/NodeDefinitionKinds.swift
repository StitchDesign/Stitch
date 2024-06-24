//
//  GraphNodeKinds.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/11/24.
//

import Foundation
import StitchSchemaKit

extension NodeKind {
    var graphNode: (any NodeDefinition.Type)? {
        switch self {
        case .patch(let patch):
            return patch.graphNode
        case .layer(let layer):
            return layer.graphNode
        case .group:
            return nil
        }
    }
}
