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
                .flatMap { keyPath in
                    layerNode[keyPath: keyPath.schemaPortKeyPath].encodedValues
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
        case .component:
            return []
        }
    }
    
    /// Helper for mutating all canvas entities under some node.
    func canvasEntityMap(_ callback: @escaping (CanvasNodeEntity) -> CanvasNodeEntity) -> NodeEntity {
    
        var nodeEntity = self
        
        switch nodeEntity.nodeTypeEntity {
        case .patch(var patch):
            patch.canvasEntity = callback(patch.canvasEntity)
            nodeEntity.nodeTypeEntity = .patch(patch)
            return nodeEntity
            
        case .layer(var layer):
            layer.layer.layerGraphNode.inputDefinitions.forEach { layerInput in
                var inputPortSchema = layer[keyPath: layerInput.schemaPortKeyPath]
                
                inputPortSchema.packedData.canvasItem =  inputPortSchema.packedData.canvasItem.map(callback)
                
                inputPortSchema.unpackedData = inputPortSchema.unpackedData.map { unpackedData in
                    var unpackedData = unpackedData
                    unpackedData.canvasItem = unpackedData.canvasItem.map(callback)
                    return unpackedData
                }
                
                layer[keyPath: layerInput.schemaPortKeyPath] = inputPortSchema
            }
            nodeEntity.nodeTypeEntity = .layer(layer)
            return nodeEntity
            
        case .group(let canvas):
            let newCanvas = callback(canvas)
            nodeEntity.nodeTypeEntity = .group(newCanvas)
            return nodeEntity
        
        case .component(let component):
            var component = component
            let newCanvas = callback(component.canvasEntity)
            component.canvasEntity = newCanvas
            nodeEntity.nodeTypeEntity = .component(component)
            return nodeEntity
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
        case .group, .component:
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
        case .group, .component:
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
    
    var componentNodeEntity: ComponentEntity? {
        switch self {
        case .component(let componentNodeEntity):
            return componentNodeEntity
        default:
            return nil
        }
    }
}

extension [NodeEntity] {
    @MainActor
    func getComponentData(masterComponentsDict: [UUID : StitchMasterComponent]) -> [StitchComponent] {
        self
            .compactMap { $0.nodeTypeEntity.componentNodeEntity?.componentId }
            .toSet
            .compactMap { masterComponentsDict.get($0)?.lastEncodedDocument }
    }
}
