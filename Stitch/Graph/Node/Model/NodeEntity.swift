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
        self.nodeTypeEntity.kind
    }
    
    /// Gets inputs values from disconnected ports.
    var encodedInputsValues: [PortValues?] {
        switch self.nodeTypeEntity {
        case .layer(let layerNode):
            // Layer nodes save values data directy in its schema
            return layerNode.layer.layerGraphNode.inputDefinitions
                .map { keyPath in
                    layerNode[keyPath: keyPath.schemaPortKeyPath].values
                }
        case .patch(let patchNode):
            return patchNode.inputs.map { $0.portData.values }
        default:
            return []
        }
    }
    
    var canvasEntities: [CanvasNodeEntity] {
        switch self.nodeTypeEntity {
        case .patch(let patch):
            return [patch.canvasEntity]
        case .layer(let layer):
            return layer.layer.layerGraphNode.inputDefinitions.flatMap {
                layer[keyPath: $0.schemaPortKeyPath].canvasItems
            }
        case .group(let canvas):
            return [canvas]
        }
    }
    
    /// Helper for mutating all canvas entities under some node.
    mutating func canvasEntityMap(_ callback: @escaping (CanvasNodeEntity) -> CanvasNodeEntity) {
        switch self.nodeTypeEntity {
        case .patch(var patch):
            patch.canvasEntity = callback(patch.canvasEntity)
            self.nodeTypeEntity = .patch(patch)
        case .layer(var layer):
            // TODO: come back to copying to determine how we should map back to layer entity
            fatalError()
//            layer.layer.layerGraphNode.inputDefinitions.forEach { layerInput in
//                layer[keyPath: layerInput.schemaPortKeyPath].canvasItems.forEach { canvas in
//                    let newCanvas = callback(canvas)
//                    layer[keyPath: layerInput.schemaPortKeyPath].canvasItem = newCanvas
//                }
//            }
            
            self.nodeTypeEntity = .layer(layer)
        case .group(let canvas):
            let newCanvas = callback(canvas)
            self.nodeTypeEntity = .group(newCanvas)
        }
    }
    
    var layerNodeEntity: LayerNodeEntity? {
        switch self.nodeTypeEntity {
        case .layer(let layer):
            return layer
        default:
            return nil
        }
    }
    
    var inputs: [NodeConnectionType] {
        switch self.nodeTypeEntity {
        case .patch(let patch):
            return patch.inputs.map { $0.portData }
        case .layer(let layer):
            return layer.layer.layerGraphNode.inputDefinitions.flatMap {
                layer[keyPath: $0.schemaPortKeyPath].inputConnections
            }
        case .group:
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
