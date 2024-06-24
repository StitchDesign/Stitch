//
//  NodeEntity.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/1/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension NodeEntity {
    var kind: NodeKind {
        if let layerNode = self.layerNodeEntity {
            return .layer(layerNode.layer)
        } else if let patchNode = self.patchNodeEntity {
            return .patch(patchNode.patch)
        }

        // Group if all else fails
        return .group
    }
    
    /// Gets inputs values from disconnected ports.
    var encodedInputsValues: [PortValues?] {
        if let layerNode = self.layerNodeEntity {
            // Layer nodes save values data directy in its schema
            return layerNode.layer.layerGraphNode.inputDefinitions
                .map { keyPath in
                    layerNode[keyPath: keyPath.schemaPortKeyPath].values
                }
        }
        
        return self.inputs.map { $0.values }
    }
}
