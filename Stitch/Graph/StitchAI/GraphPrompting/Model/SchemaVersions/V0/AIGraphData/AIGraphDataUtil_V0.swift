//
//  AIGraphDataUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/15/25.
//

import SwiftUI
import StitchSchemaKit

enum AICodeGenError: Error {
    case nodeDataNotFound
}

extension AIGraphData_V0 {
    typealias GraphEntity = GraphEntity_V32.GraphEntity
    typealias NodeEntity = NodeEntity_V32.NodeEntity
    typealias PatchNodeEntity = PatchNodeEntity_V32.PatchNodeEntity
    typealias LayerNodeEntity = LayerNodeEntity_V32.LayerNodeEntity
    typealias SidebarLayerData = SidebarLayerData_V32.SidebarLayerData
    typealias NodeType = UserVisibleType_V32.UserVisibleType
    typealias JavaScriptNodeSettings = JavaScriptNodeSettings_V32.JavaScriptNodeSettings
    typealias JavaScriptPortDefinition = JavaScriptPortDefinition_V32.JavaScriptPortDefinition
    typealias Patch = Patch_V32.Patch
    typealias Layer = Layer_V32.Layer
    typealias LayerInputPort = LayerInputPort_V32.LayerInputPort
    typealias StitchAIPortValue = StitchAIPortValue_V1.StitchAIPortValue
    typealias PortValueVersion = PortValue_V32
    typealias PortValue = PortValueVersion.PortValue
    typealias NodeIOPortType = NodeIOPortType_V32.NodeIOPortType
}

extension AIGraphData_V0.GraphData {
    init(from graphEntity: AIGraphData_V0.GraphEntity) throws {
        let nodesDict = graphEntity.nodes.reduce(into: [UUID : AIGraphData_V0.NodeEntity]()) { result, node in
            result.updateValue(node, forKey: node.id)
        }
        
        var jsNodes = [AIGraphData_V0.JsPatchNode]()
        var nativeNodes = [AIGraphData_V0.NativePatchNode]()
        
        for nodeEntity in graphEntity.nodes {
            switch nodeEntity.nodeTypeEntity {
            case .patch(let patchNodeEntity):
                // JS node scenario
                if let jsData = patchNodeEntity.javaScriptNodeSettings {
                    jsNodes.append( .init(from: jsData,
                                          id: patchNodeEntity.id))
                }
                
                // Native node scenario
                else {
                    nativeNodes.append(.init(node_id: patchNodeEntity.id.description,
                                             node_name: .init(value: .patch(patchNodeEntity.patch))))
                }
                
            default:
                continue
            }
        }
        
        let aiLayerData: [AIGraphData_V0.LayerData] = try graphEntity.orderedSidebarLayers
            .createAIData(nodesDict: nodesDict)
        
        fatalError()
    }
}

extension AIGraphData_V0.JsPatchNode {
    init(from jsSettings: AIGraphData_V0.JavaScriptNodeSettings,
         id: UUID) {
        self = .init(node_id: id.description,
                     javascript_source_code: jsSettings.script,
                     suggested_title: jsSettings.suggestedTitle,
                     input_definitions: jsSettings.inputDefinitions.map { JavaScriptPortDefinitionAI_V1.JavaScriptPortDefinitionAI(from: $0) },
                     output_definitions: jsSettings.outputDefinitions.map { JavaScriptPortDefinitionAI_V1.JavaScriptPortDefinitionAI(from: $0) })
    }
}

extension JavaScriptPortDefinitionAI_V1.JavaScriptPortDefinitionAI {
    init(from portSettings: AIGraphData_V0.JavaScriptPortDefinition) {
        self = .init(label: portSettings.label,
                     strict_type: portSettings.strictType)
    }
}

extension Array where Element == AIGraphData_V0.SidebarLayerData {
    func createAIData(nodesDict: [UUID : AIGraphData_V0.NodeEntity]) throws -> [AIGraphData_V0.LayerData] {
        try self.map { sidebarData in
            try .init(from: sidebarData,
                      nodesDict: nodesDict)
        }
    }
}

extension AIGraphData_V0.LayerData {
    init(from sidebarData: AIGraphData_V0.SidebarLayerData,
         nodesDict: [UUID : AIGraphData_V0.NodeEntity]) throws {
        guard let node = nodesDict.get(sidebarData.id),
              let layerData = node.layerNodeEntity else {
            throw AICodeGenError.nodeDataNotFound
        }
        
        // Recursively create children
        let children = try sidebarData.children?.createAIData(nodesDict: nodesDict)
        
        let customInputValues: [AIGraphData_V0.CustomLayerInputValue] = try LayerInputPort_V32.LayerInputPort
            .allCases.compactMap { port in
                let portData = layerData[keyPath: port.schemaPortKeyPath]
                
                switch portData.packedData.inputPort {
                case .values(let values):
                    let defaultData = port.getDefaultValueForAI(for: layerData.layer)
                    
                    // Save data if different from default value
                    if let firstValue = values.first,
                       defaultData != firstValue {
                        return try .init(id: layerData.id,
                                         input: port,
                                         value: firstValue)
                    }
                    
                    return nil
                    
                case .upstreamConnection:
                    // Ignore upstream connection
                    return nil
                }
            }
        
        self = .init(node_id: sidebarData.id.description,
                     node_name: .init(value: .layer(layerData.layer)),
                     children: children,
                     custom_layer_input_values: customInputValues)
    }
}

extension AIGraphData_V0.PatchOrLayer {
    var layer: Layer_V32.Layer? {
        switch self {
        case .layer(let layer):
            return layer
        case .patch:
            return nil
        }
    }
}

extension AIGraphData_V0.Layer {
    var isGroupForAI: Bool {
        switch self {
        case .group, .realityView:
            return true
            
        default:
            return false
        }
    }
}

extension AIGraphData_V0.NodeType {
    /// Migrates Stitch AI's node type to runtime.
    func migrate() throws -> NodeType {
        try NodeTypeVersion.migrate(entity: self,
                                    version: CurrentStep.documentVersion)
    }
}
