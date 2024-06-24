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
        self.nodeEntityType.kind
    }
    
    /// Gets inputs values from disconnected ports.
    var encodedInputsValues: [PortValues?] {
        switch self.nodeEntityType {
        case .layer(let layerNode):
            // Layer nodes save values data directy in its schema
            return layerNode.layer.layerGraphNode.inputDefinitions
                .map { keyPath in
                    layerNode[keyPath: keyPath.schemaPortKeyPath].values
                }
        case .patch(let patchNode):
            return patchNode.inputs.map { $0.values }
        default:
            return []
        }
        
    }
}

extension NodeTypeEntity {
    var kind: NodeKind {
        switch self {
        case .patch(let patchEntity):
            return .patch(patchEntity.patch)
        case .layer(let layerEntity):
            return .layer(layerEntity.layer)
        case .group:
            return .group
        }
    }
    
    var patchNodeEntity: PatchNodeEntity? {
        switch self {
        case .patch(let patchNodeEntity):
            return patchNodeEntity
        default:
            return nil
        }
    }
    
    var layerNodeEntity: LayerNodeEntity? {
        switch self {
        case .layer(let layerNodeEntity):
            return layerNodeEntity
        default:
            return nil
        }
    }
}
