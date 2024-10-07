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
    mutating func canvasEntityMap(_ callback: @escaping (CanvasNodeEntity) -> CanvasNodeEntity) {
        switch self.nodeTypeEntity {
        case .patch(var patch):
            patch.canvasEntity = callback(patch.canvasEntity)
            self.nodeTypeEntity = .patch(patch)
        case .layer(var layer):
            // Update packed and unpacked canvas items, if they exist
            layer.layer.layerGraphNode.inputDefinitions.forEach { layerInput in
                var inputPortSchema = layer[keyPath: layerInput.schemaPortKeyPath]
                
                if let packedCanvas = inputPortSchema.packedData.canvasItem {
                    inputPortSchema.packedData.canvasItem = callback(packedCanvas)
                }
                
                inputPortSchema.unpackedData = inputPortSchema.unpackedData.map { unpackedData in
                    var unpackedData = unpackedData
                    if let canvas = unpackedData.canvasItem {
                        unpackedData.canvasItem = callback(canvas)
                    }
                    return unpackedData
                }
            }
            
            self.nodeTypeEntity = .layer(layer)
        case .group(let canvas):
            let newCanvas = callback(canvas)
            self.nodeTypeEntity = .group(newCanvas)
        case .component(let component):
            var component = component
            let newCanvas = callback(component.canvasEntity)
            component.canvasEntity = newCanvas
            self.nodeTypeEntity = .component(component)
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
    func getComponentData(masterComponentsDict: [UUID : StitchMasterComponent]) -> [StitchComponentData] {
        self
            .compactMap { $0.nodeTypeEntity.componentNodeEntity?.componentId }
            .toSet
            .compactMap { masterComponentsDict.get($0)?.componentData }
    }
}
