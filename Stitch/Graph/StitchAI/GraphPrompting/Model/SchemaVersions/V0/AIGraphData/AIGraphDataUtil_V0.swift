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

extension AIGraphData_V0.GraphData {
    init(from graphEntity: AIGraphData_V0.GraphEntity) throws {
        let nodesDict = graphEntity.nodes.reduce(into: [UUID : AIGraphData_V0.NodeEntity]()) { result, node in
            result.updateValue(node, forKey: node.id)
        }
        
        // Maps upstream patch output coordinate to some new created @State var name
        var viewStatePatchConnections: [String : [NodeConnectionType]] = [:]
        
        // Maps interactions to layers, used to determine gestures to create
        // Key = Patch, Value = Layer
        var patchToLayerAssignmentMap: [UUID : UUID] = [:]
        
        // Maps each interaction-enabled layer to a patch, used for determining state mutations in gesture closure
        // Key: input coordinate, Value: output coordinate of patch interaction
        var upstreamConnectionToInteraction: [NodeIOCoordinate : NodeIOCoordinate] = [:]
        
        // First pass--create nodes and assign types
        for nodeEntity in graphEntity.nodes {
            switch nodeEntity.nodeTypeEntity {
            case .patch(let patchNodeEntity):
                // Interactions are handled within layers
                if patchNodeEntity.patch.isInteractionPatchNode {
                    if let assignedLayer = patchNodeEntity.inputs.first?.portData.values?.first?.getInteractionId {
                        patchToLayerAssignmentMap.updateValue(assignedLayer.id, forKey: patchNodeEntity.id)
                    }
                }
                
            default:
                continue
            }
        }
        
        // Second pass, delayed for tracking all interaction data
        for nodeEntity in graphEntity.nodes {
            switch nodeEntity.nodeTypeEntity {
            case .patch(let patchNodeEntity):
                // Add custom input value events
                for (portIndex, inputData) in patchNodeEntity.inputs.enumerated() {
                    switch inputData.portData {
                    case .values(let values):
                        continue
                        
                    case .upstreamConnection(let upstream):
                        if let upstreamPortIndex = upstream.portId {
                            let isInteractionUpstream = patchToLayerAssignmentMap.keys.contains(upstream.nodeId)
                            
                            // Track interaction data differently
                            if isInteractionUpstream {
                                upstreamConnectionToInteraction.updateValue(upstream,
                                                                            forKey: .init(portId: portIndex,
                                                                                          nodeId: patchNodeEntity.id))
                            }
                        }
                    }
                }
            default:
                continue
            }
        }
        
        let aiLayerData: [AIGraphData_V0.LayerData] = try graphEntity.orderedSidebarLayers
            .createAIData(nodesDict: nodesDict,
                          patchToLayerAssignmentMap: patchToLayerAssignmentMap,
                          upstreamConnectionToInteraction: &upstreamConnectionToInteraction,
                          viewStatePatchConnections: &viewStatePatchConnections)
        
        self = .init(layer_data_list: aiLayerData,
                     patchNodes: graphEntity.nodes.filter { $0.nodeTypeEntity.patchNodeEntity != nil },
                     viewStatePatchConnections: viewStatePatchConnections)
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
                      patchToLayerAssignmentMap: [UUID : UUID],
                      upstreamConnectionToInteraction: inout [NodeIOCoordinate : NodeIOCoordinate],
                      viewStatePatchConnections: inout [String : [NodeConnectionType]]) throws -> [AIGraphData_V0.LayerData] {
        try self.map { sidebarData in
            try .init(from: sidebarData,
                      nodesDict: nodesDict,
                      patchToLayerAssignmentMap: patchToLayerAssignmentMap,
                      upstreamConnectionToInteraction: &upstreamConnectionToInteraction,
                      viewStatePatchConnections: &viewStatePatchConnections)
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
         patchToLayerAssignmentMap: [UUID : UUID],
         upstreamConnectionToInteraction: inout [NodeIOCoordinate : NodeIOCoordinate],
         viewStatePatchConnections: inout [String : [NodeConnectionType]]) throws {
        guard let node = nodesDict.get(sidebarData.id),
              let layerData = node.layerNodeEntity else {
            throw AICodeGenError.nodeDataNotFound
        }
                
        // Recursively create children
        let children = try sidebarData.children?.createAIData(nodesDict: nodesDict,
                                                              patchToLayerAssignmentMap: patchToLayerAssignmentMap,
                                                              upstreamConnectionToInteraction: &upstreamConnectionToInteraction,
                                                              viewStatePatchConnections: &viewStatePatchConnections)
        
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
//                    let layerConnection = try Self
//                        .createLayerConnection(upstream: upstream,
//                                               downstreamNodeId: layerData.id,
//                                               downstreamPort: port,
//                                               downstreamKeyPathType: .packed)
                    let isInteractionUpstream = patchToLayerAssignmentMap.keys.contains(upstream.nodeId)
                    
                    // Upstream connections require @State variable, so we'll make one here
                    let stateVarName = port.asLLMStepPort
                        .toCamelCase()
                        .createUniqueVarName(nodeId: layerData.id)
                    
                    customInputValues.append(
                        .init(input: port,
                              inputData: [.connectionToLayerInput(stateVarName)])
                    )
                    
                    // Update state dict
                    viewStatePatchConnections
                        .updateValue(.upstreamConnection(upstream),
                                     forKey: stateVarName)
                    
                    // Track interaction data
                    if isInteractionUpstream {
                        upstreamConnectionToInteraction.updateValue(
                            upstream,
                            forKey: .init(portType: .keyPath(.init(layerInput: port,
                                                                   portType: .packed)),
                                          nodeId: node.id)
                        )
                    }
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
                            inputData: [.portData(.values([firstValue]))]
                        ))
                        
                    case .upstreamConnection(let upstream):                        
                        // Upstream connections require @State variable, so we'll make one here
                        let prefixName = "\(port.asLLMStepPort.toCamelCase())_\(portIndex)"
                        let stateVarName = prefixName.createUniqueVarName(nodeId: layerData.id)
                        
                        customInputValues.append(
                            .init(input: port,
                                  inputData: [.connectionToLayerInput(stateVarName)])
                        )
                        
                        // Update state dict
                        viewStatePatchConnections
                            .updateValue(.upstreamConnection(upstream),
                                         forKey: stateVarName)
                    }
                }
            }
        }
        
        // Determine view events
        let viewEvents: [SwiftPatchViewEvent] = patchToLayerAssignmentMap.flatMap { interactionToLayer -> [SwiftPatchViewEvent] in
            let (patchInteractionId, layerId) = interactionToLayer
            
            // Ensure that interactions are only for this layer
            guard layerId == sidebarData.id else {
                return []
            }
            
            let outputPortIdsUsedFromInteraction = upstreamConnectionToInteraction.values
                .compactMap { upstreamInteractionCoordinate -> Int? in
                    guard upstreamInteractionCoordinate.nodeId == patchInteractionId else {
                        return nil
                    }
                    
                    return upstreamInteractionCoordinate.portId
                }
                .toSet

            switch nodesDict.get(patchInteractionId)?.kind {
            case .patch(let patch):
                return outputPortIdsUsedFromInteraction.map { outputPortId in
                    let interactionOutputCoordinate = NodeIOCoordinate(
                        portId: outputPortId, nodeId: patchInteractionId)

                    let _viewEventName = patch.syntaxViewEvent
                    assertInDebug(_viewEventName != nil)
                    let viewEventName = _viewEventName ?? .dragGesture
                    
                    let gestureProperty = patch.getGestureName(for: outputPortId)
                    let stateVarName = patch.createInteractionStateVarName(layerId: layerData.id,
                                                                           outputPortIndex: outputPortId)
                    
                    // Check for state var names to override if redundant state vars were made for connected layer inputs
                    viewStatePatchConnections = viewStatePatchConnections.reduce(into: viewStatePatchConnections) { result, connectionData in
                        let (oldKey, viewStateUpstreamCoordinates) = connectionData
                        
                        // Multiple only expected when parsing AI result
                        assertInDebug(viewStateUpstreamCoordinates.count == 1)
                        
                        guard let viewStateUpstreamCoordinate = viewStateUpstreamCoordinates.first else {
                            fatalErrorIfDebug()
                            return
                        }
                        
                        if viewStateUpstreamCoordinate.upstreamConnection == interactionOutputCoordinate {
                            // Update key
                            result.removeValue(forKey: oldKey)
                            result.updateValue(viewStateUpstreamCoordinate,
                                               forKey: stateVarName)
                        }
                    }
                    
                    // MARK: definitely misisng arg info but works for now
                    return .init(viewEvent: .init(layerId: layerData.id,
                                                  type: viewEventName,
                                                  gestureArg: "g"),
                                 codeStatements: [(stateVarName, .expression(.ref("g.\(gestureProperty)")))])
                }
            
            default:
                fatalErrorIfDebug()
                return []
            }
        }
        
        self = .init(node_id: sidebarData.id.description,
                     node_name: .init(value: .layer(layerData.layer)),
                     children: children,
                     custom_layer_input_values: customInputValues,
                     view_events: viewEvents)
    }
}

extension AIGraphData_V0.PatchOrLayer {
    var patch: Patch? {
        switch self {
        case .layer:
            return nil
        case .patch(let patch):
            return patch
        }
    }

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
