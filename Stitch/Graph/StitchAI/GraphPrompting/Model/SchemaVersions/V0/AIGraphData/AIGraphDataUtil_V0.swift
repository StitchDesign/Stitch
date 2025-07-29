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
    static let documentVersion = StitchSchemaVersion._V33
    
    typealias GraphEntity = GraphEntity_V33.GraphEntity
    typealias NodeEntity = NodeEntity_V33.NodeEntity
    typealias PatchNodeEntity = PatchNodeEntity_V33.PatchNodeEntity
    typealias LayerNodeEntity = LayerNodeEntity_V33.LayerNodeEntity
    typealias SidebarLayerData = SidebarLayerData_V33.SidebarLayerData
    typealias NodeType = UserVisibleType_V33.UserVisibleType
    typealias JavaScriptNodeSettings = JavaScriptNodeSettings_V33.JavaScriptNodeSettings
    typealias JavaScriptPortDefinition = JavaScriptPortDefinition_V33.JavaScriptPortDefinition
    typealias Patch = Patch_V33.Patch
    typealias Layer = Layer_V33.Layer
    typealias LayerInputPort = LayerInputPort_V33.LayerInputPort
    typealias LayerInputType = LayerInputType_V33.LayerInputType
    typealias StitchAIPortValue = StitchAIPortValue_V1.StitchAIPortValue
    typealias PortValueVersion = PortValue_V33
    typealias PortValue = PortValueVersion.PortValue
    typealias NodeIOPortType = NodeIOPortType_V33.NodeIOPortType
}

extension AIGraphData_V0.CodeCreatorParams {
    init(from graphEntity: AIGraphData_V0.GraphEntity) throws {
        let nodesDict = graphEntity.nodes.reduce(into: [UUID : AIGraphData_V0.NodeEntity]()) { result, node in
            result.updateValue(node, forKey: node.id)
        }
        
        var jsNodes = [AIGraphData_V0.JsPatchNode]()
        var nativeNodes = [AIGraphData_V0.NativePatchNode]()
        var nodeTypeSettings = [AIGraphData_V0.NativePatchNodeValueTypeSetting]()
        var patchConnections = [AIGraphData_V0.PatchConnection]()
        var customPatchInputs = [AIGraphData_V0.CustomPatchInputValue]()
        var layerConnections = [AIGraphData_V0.LayerConnection]()
        
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
                    nativeNodes.append(.init(node_id: patchNodeEntity.id.uuidString,
                                             node_name: .init(value: .patch(patchNodeEntity.patch))))
                    
                    // Update node type
                    if let type = patchNodeEntity.userVisibleType {
                        nodeTypeSettings.append(.init(node_id: patchNodeEntity.id.description,
                                                      value_type: .init(value: type)))
                    }
                }
                
                // Add custom input value events
                for (portIndex, inputData) in patchNodeEntity.inputs.enumerated() {
                    switch inputData.portData {
                    case .values(let values):
                        if let firstValue = values.first {
                            customPatchInputs.append(
                                .init(patch_input_coordinate: .init(node_id: patchNodeEntity.id.description,
                                                                    port_index: portIndex),
                                      value: firstValue.anyCodable,
                                      value_type: .init(value: firstValue.nodeType))
                            )
                        }
                        
                    case .upstreamConnection(let upstream):
                        if let upstreamPortIndex = upstream.portId {
                            patchConnections.append(
                                .init(src_port: .init(node_id: upstream.nodeId.description,
                                                      port_index: upstreamPortIndex),
                                      dest_port: .init(node_id: patchNodeEntity.id.description,
                                                       port_index: portIndex))
                            )
                        }
                    }
                }
                
            default:
                continue
            }
        }
        
        let aiLayerData: [AIGraphData_V0.LayerData] = try graphEntity.orderedSidebarLayers
            .createAIData(nodesDict: nodesDict,
            layerConnections: &layerConnections)
        
        self = .init(layer_data_list: try aiLayerData.encodeToString(),
                     patch_data: .init(javascript_patches: jsNodes,
                                       native_patches: nativeNodes,
                                       native_patch_value_type_settings: nodeTypeSettings,
                                       patch_connections: patchConnections,
                                       custom_patch_input_values: customPatchInputs,
                                       layer_connections: layerConnections))
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
    func createAIData(nodesDict: [UUID : AIGraphData_V0.NodeEntity],
                      layerConnections: inout [AIGraphData_V0.LayerConnection]) throws -> [AIGraphData_V0.LayerData] {
        try self.map { sidebarData in
            try .init(from: sidebarData,
                      nodesDict: nodesDict,
                      layerConnections: &layerConnections)
        }
    }
}

extension Array where Element == AIGraphData_V0.LayerData {
    var allFlattenedItems: [AIGraphData_V0.LayerData] {
        self.flatMap { item in
            [item] + (item.children?.allFlattenedItems ?? [])
        }
    }
}

extension AIGraphData_V0.LayerData {
    init(from sidebarData: AIGraphData_V0.SidebarLayerData,
         nodesDict: [UUID : AIGraphData_V0.NodeEntity],
         layerConnections: inout [AIGraphData_V0.LayerConnection]) throws {
        guard let node = nodesDict.get(sidebarData.id),
              let layerData = node.layerNodeEntity else {
            throw AICodeGenError.nodeDataNotFound
        }
        
        // Recursively create children
        let children = try sidebarData.children?.createAIData(nodesDict: nodesDict,
                                                              layerConnections: &layerConnections)
        
        var customInputValues = [LayerPortDerivation]()
        for port in LayerInputPort.allCases {
            let portData = layerData[keyPath: port.schemaPortKeyPath]
            
            switch portData.mode {
            case .packed:
                switch portData.packedData.inputPort {
                case .values(let values):
                    let defaultData = port.getDefaultValueForAI(for: layerData.layer)
                    let defaultEncodedData = try defaultData.anyCodable.encodeToData()
                    
                    // Save data if different from default value
                    if let firstValue = values.first {
                        let firstValueEncodedData = try firstValue.anyCodable.encodeToData()
                        
                        // Check if values are equal
                        if defaultData != firstValue &&
                            // Redundant check because sometimes values are the same but different (like for color)
                            defaultEncodedData != firstValueEncodedData {
                            customInputValues.append(
                                .init(input: port,
                                      value: firstValue)
                            )
                        }
                    }
                    
                case .upstreamConnection(let upstream):
                    let layerConnection = try Self
                        .createLayerConnection(upstream: upstream,
                                               downstreamNodeId: layerData.id,
                                               downstreamPort: port,
                                               downstreamKeyPathType: .packed)
                    
                    layerConnections.append(layerConnection)
                }
                
            case .unpacked:
                for (portIndex, unpackedData) in portData.unpackedData.enumerated() {
                    guard let unpackedPortType = UnpackedPortType_V33.UnpackedPortType(rawValue: portIndex) else {
                        fatalErrorIfDebug()
                        continue
                    }
                    
                    switch unpackedData.inputPort {
                    case .values(let values):
                        guard let firstValue = values.first else {
                            fatalErrorIfDebug()
                            continue
                        }
                        
                        customInputValues.append(.init(
                            coordinate: .init(
                                layerInput: port,
                                portType: .unpacked(unpackedPortType)),
                            inputData: .value(.init(firstValue))
                        ))
                        
                    case .upstreamConnection(let upstream):
                        let layerConnection = try Self
                            .createLayerConnection(upstream: upstream,
                                                   downstreamNodeId: layerData.id,
                                                   downstreamPort: port,
                                                   downstreamKeyPathType: .unpacked(unpackedPortType))
                        
                        layerConnections.append(layerConnection)
                    }
                }
            }
        }
        
        self = .init(node_id: sidebarData.id.description,
                     node_name: .init(value: .layer(layerData.layer)),
                     children: children,
                     custom_layer_input_values: customInputValues)
    }
    
    static func createLayerConnection(upstream: NodeIOCoordinate,
                                      downstreamNodeId: UUID,
                                      downstreamPort: LayerInputPort,
                                      downstreamKeyPathType: LayerInputKeyPathType) throws -> AIGraphData_V0.LayerConnection {
        guard let upstreamPortIndex = upstream.portId else {
            throw SwiftUISyntaxError.unexpectedUpstreamLayerCoordinate
        }
            
        return .init(
            src_port: .init(node_id: upstream.nodeId.description,
                            port_index: upstreamPortIndex),
            dest_port: .init(layer_id: downstreamNodeId.description,
                             input_port_type: .init(layerInput: downstreamPort,
                                                    portType: downstreamKeyPathType)
                            )
        )
    }
}

extension AIGraphData_V0.PatchOrLayer {
    var layer: Layer? {
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
                                    version: AIGraphData_V0.documentVersion)
    }
}
