//
//  AIPatchBuilderResponseFormat_V).swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import SwiftUI
import StitchSchemaKit

enum AIPatchBuilderResponseFormat_V0 {
    struct AIPatchBuilderResponseFormat: OpenAIResponseFormatable {
        let type = "json_schema"
        let json_schema = AIPatchBuilderJsonSchema()
    }

    struct AIPatchBuilderJsonSchema: OpenAIJsonSchema {
        let name = "GraphBuilder"
        let schema = PatchBuilderStructuredOutputsPayload()
    }
    
    struct PatchBuilderStructuredOutputsPayload: OpenAISchemaDefinable {
        let defs = PatchBuilderStructuredOutputsDefinitions()
        let schema = OpenAISchema(type: .object,
                                  properties: AIPatchBuilderResponseFormat_V0.GraphBuilderSchema(),
                                  required: ["javascript_patches", "native_patches", "patch_connections", "layer_connections", "custom_patch_input_values"])
        let strict = true
    }

    struct PatchBuilderStructuredOutputsDefinitions: Encodable {
        // Value Types
        let ValueType = OpenAISchemaEnum(values: Step_V0.NodeType.allCases
            .filter { $0 != .none }
            .map { $0.asLLMStepNodeType }
        )
        
        // Node Kinds
        let NodeName = OpenAISchemaEnum(values: Step_V0.NodeKind.getAiNodeDescriptions().map(\.nodeKind))
        
        let LayerPorts = OpenAISchemaEnum(values: Step_V0.LayerInputPort.allCases
            .map { $0.asLLMStepPort }
        )
        
        let Layer_Nodes = OpenAISchema(
            type: .array,
            required: ["node_id", "node_name", "custom_layer_input_values"],
            description: "A nested list of layer nodes to be created in the graph.",
            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.LayerNodeSchema()])
        )
        
        let Values = OpenAIGeneric(types: [
            OpenAISchema(type: .number),
            OpenAISchema(type: .string),
            OpenAISchema(type: .boolean),
            OpenAISchema(type: .object, additionalProperties: false)
          ])
        
        let PatchCoordinate = OpenAISchema(
            type: .object,
            properties: NodeIndexedCoordinateSchema(),
            required: ["node_id", "port_index"])
        
        let LayerInputCoordinate = OpenAISchema(
            type: .object,
            properties: LayerInputCoordinateSchema(),
            required: ["layer_id", "input_port_type"])
    }
    
    struct GraphBuilderSchema: Encodable {
        let javascript_patches = OpenAISchema(
            type: .array,
            required: ["node_id", "suggested_title", "javascript_source_code", "input_definitions", "output_definitions"],
            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.JsPatchNodeSchema()])
        )
        
        let native_patches = OpenAISchema(
            type: .array,
            required: ["node_id", "node_name"],
            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.NativePatchNodeSchema()])
        )
        
        let patch_connections = OpenAISchema(
            type: .array,
            required: ["src_port", "dest_port"],
            items: OpenAIGeneric(types: [
                AIPatchBuilderResponseFormat_V0.PatchConnectionSchema()
            ])
        )
        
        let layer_connections = OpenAISchema(
            type: .array,
            required: ["src_port", "dest_port"],
            items: OpenAIGeneric(types: [
                AIPatchBuilderResponseFormat_V0.LayerConnectionSchema()
            ])
        )

        let custom_patch_input_values = OpenAISchema(
            type: .array,
            required: ["patch_input_coordinate", "value", "value_type"],
            items: OpenAIGeneric(types: [
                AIPatchBuilderResponseFormat_V0.CustomPatchInputValueSchema()
            ])
        )
    }
    
    // MARK: not used for outputs, just inputs.
    struct LayerNodeSchema: Encodable {
        let node_id = OpenAISchema(type: .string)
        let suggested_title = OpenAISchema(type: .string)
        let node_name = OpenAISchemaRef(ref: "NodeName")
        let children = OpenAISchemaRef(ref: "Layer_Nodes")
        let custom_layer_input_values = OpenAISchema(
            type: .array,
            required: ["layer_input_coordinate", "value", "value_type"],
            items: OpenAIGeneric(types: [
                AIPatchBuilderResponseFormat_V0.CustomLayerInputValueSchema()
            ])
        )
    }

    struct JsPatchNodeSchema: Encodable {
        static let portDefinitions = AIEditJsNodeResponseFormat_V0.JsNodeSettingsSchema.portDefinitions
        
        let node_id = OpenAISchema(type: .string)
        let suggested_title = OpenAISchema(type: .string)
        let javascript_source_code = OpenAISchema(type: .string)
        let input_definitions = Self.portDefinitions
        let output_definitions = Self.portDefinitions
    }
    
    struct NativePatchNodeSchema: Encodable {
        let node_id = OpenAISchema(type: .string)
        let node_name = OpenAISchemaRef(ref: "NodeName")
    }
    
    struct PatchConnectionSchema: Encodable {
        let src_port = OpenAISchemaRef(ref: "PatchCoordinate")
        let dest_port = OpenAISchemaRef(ref: "PatchCoordinate")
    }
    
    struct LayerConnectionSchema: Encodable {
        let src_port = OpenAISchemaRef(ref: "PatchCoordinate")
        let dest_port = OpenAISchemaRef(ref: "LayerInputCoordinate")
    }
    
    struct CustomPatchInputValueSchema: Encodable {
        let patch_input_coordinate = OpenAISchemaRef(ref: "PatchCoordinate")
        let value = OpenAISchemaRef(ref: "Values")
        let value_type = OpenAISchemaRef(ref: "ValueType")
    }
    
    struct CustomLayerInputValueSchema: Encodable {
        let layer_input_coordinate = OpenAISchemaRef(ref: "LayerInputCoordinate")
        let value = OpenAISchemaRef(ref: "Values")
        let value_type = OpenAISchemaRef(ref: "ValueType")
    }
    
    struct NodeIndexedCoordinateSchema: Encodable {
        let node_id = OpenAISchema(type: .string)
        let port_index = OpenAISchema(type: .integer)
    }
    
    struct LayerInputCoordinateSchema: Encodable {
        let layer_id = OpenAISchema(type: .string)
        let input_port_type = OpenAISchemaRef(ref: "LayerPorts")
    }

    struct PortDefinitionSchema: Encodable {
        let label = OpenAISchema(type: .string)
        let strict_type = OpenAISchemaRef(ref: "ValueType")
    }
}

// Actual types
extension AIPatchBuilderResponseFormat_V0 {
    struct GraphData: Codable {
        let layer_data: [LayerData]
        let patch_data: PatchData
    }
    
    struct PatchData: Codable {
        let javascript_patches: [AIPatchBuilderResponseFormat_V0.JsPatchNode]
        let native_patches: [AIPatchBuilderResponseFormat_V0.NativePatchNode]
        let patch_connections: [PatchConnection]
        let custom_patch_input_values: [CustomPatchInputValue]
    
        // All connections are captured by patch data regardless of patch or layer
        let layer_connections: [LayerConnection]
    }

    struct LayerData {
        let node_id: StitchAIUUID_V0.StitchAIUUID
        var suggested_title: String?
        let node_name: StitchAIPatchOrLayer
        var children: [LayerData]?
        var custom_layer_input_values: [CustomLayerInputValue] = []
    }
    
    struct JsPatchNode: Codable {
        let node_id: StitchAIUUID_V0.StitchAIUUID
        let javascript_source_code: String
        let suggested_title: String
        let input_definitions: [JavaScriptPortDefinitionAI_V0.JavaScriptPortDefinitionAI]
        let output_definitions: [JavaScriptPortDefinitionAI_V0.JavaScriptPortDefinitionAI]
    }
    
    struct NativePatchNode: Codable {
        let node_id: StitchAIUUID_V0.StitchAIUUID
        let node_name: StitchAIPatchOrLayer
    }
    
    struct PatchConnection: Codable {
        let src_port: NodeIndexedCoordinate   // source node's output port
        let dest_port: NodeIndexedCoordinate  // destination patch node's input port
    }
    
    struct LayerConnection: Codable {
        let src_port: NodeIndexedCoordinate   // source node's output port
        let dest_port: LayerInputCoordinate   // destination patch node's input port
    }
    
    struct LayerInputCoordinate: Codable {
        let layer_id: StitchAIUUID_V0.StitchAIUUID
        let input_port_type: AILayerInputPort
    }

    struct NodeIndexedCoordinate: Codable {
        let node_id: StitchAIUUID_V0.StitchAIUUID
        let port_index: Int
    }
    
    struct CustomPatchInputValue: Codable {
        let patch_input_coordinate: NodeIndexedCoordinate
        let value: Step_V0.PortValue
    }
    
    struct CustomLayerInputValue: Codable {
        let layer_input_coordinate: LayerInputCoordinate
        let value: Step_V0.PortValue
    }
    
    struct AILayerInputPort {
        var value: LayerInputPort_V31.LayerInputPort
    }
    
    struct StitchAIPatchOrLayer: StitchAIStringConvertable {
        var value: Step_V0.PatchOrLayer
    }
}

extension Step_V0.PatchOrLayer: StitchAIValueStringConvertable {
    var encodableString: String {
        self.asLLMStepNodeName
    }
    
    public init?(_ description: String) {
        do {
            self = try Self.fromLLMNodeName(description)
        } catch {
            fatalErrorIfDebug("PatchOrLayer error: \(error.localizedDescription)")
            return nil
        }
    }
}

extension AIPatchBuilderResponseFormat_V0.AILayerInputPort: Codable {
    /// Decodes a value that could be string, int, double, or JSON
    /// - Parameter decoder: The decoder to read from
    /// - Throws: DecodingError if value cannot be converted to string
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding as different types, converting each to string
        if let stringValue = try? container.decode(String.self),
           let valueFromString = LayerInputPort_V31.LayerInputPort.allCases
            .first(where: { $0.asLLMStepPort == stringValue }) {
            self.init(value: valueFromString)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "StitchAIStringConvertable: unexpected type for \(AIPatchBuilderResponseFormat_V0.AILayerInputPort.self)"
                )
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.value.asLLMStepPort)
    }
}

extension AIPatchBuilderResponseFormat_V0.CustomPatchInputValue {
    enum CodingKeys: String, CodingKey {
        case patch_input_coordinate
        case value
        case value_type
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.patch_input_coordinate = try container
            .decode(AIPatchBuilderResponseFormat_V0.NodeIndexedCoordinate.self,
                    forKey: .patch_input_coordinate)
        self.value = try Step_V0.PortValue.decodeFromAI(container: container,
                                                        valueKey: .value,
                                                        valueTypeKey: .value_type)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(patch_input_coordinate, forKey: .patch_input_coordinate)
        try Step_V0.PortValue.encodeFromAI(container: &container,
                                           portValue: self.value,
                                           valueKey: .value,
                                           valueTypeKey: .value_type)
    }
}

extension AIPatchBuilderResponseFormat_V0.LayerData: Codable {
    enum CodingKeys: String, CodingKey {
        case node_id
        case suggested_title
        case node_name
        case children
        case custom_layer_input_values
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(node_id, forKey: .node_id)
        try container.encode(node_name, forKey: .node_name)
        try container.encode(custom_layer_input_values, forKey: .custom_layer_input_values)
        
        try container.encodeIfPresent(suggested_title, forKey: .suggested_title)
        
        // Only encode children if group layer
        try container.encodeIfPresent(children, forKey: .children)
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        node_id = try container.decode(StitchAIUUID_V0.StitchAIUUID.self, forKey: .node_id)
        suggested_title = try container.decodeIfPresent(String.self, forKey: .suggested_title)
        node_name = try container.decode(AIPatchBuilderResponseFormat_V0.StitchAIPatchOrLayer.self, forKey: .node_name)
        
        if let children = try container.decodeIfPresent([Self].self, forKey: .children) {
            self.children = children
        } else {
            // Make sure we have an empty list if layer is a group
            if node_name.value == .layer(.group) || node_name.value == .layer(.realityView) {
                self.children = []
            }
        }
    }
}

extension AIPatchBuilderResponseFormat_V0.CustomLayerInputValue {
    init(id: UUID,
         input: Step_V0.LayerInputPort,
         value: Step_V0.PortValue) {
        self = .init(layer_input_coordinate: .init(
            layer_id: .init(value: id),
            input_port_type: .init(value: input)),
                     value: value)
    }
}

extension AIPatchBuilderResponseFormat_V0.CustomLayerInputValue {
    enum CodingKeys: String, CodingKey {
        case layer_input_coordinate
        case value
        case value_type
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.layer_input_coordinate = try container
            .decode(AIPatchBuilderResponseFormat_V0.LayerInputCoordinate.self,
                    forKey: .layer_input_coordinate)
        self.value = try Step_V0.PortValue.decodeFromAI(container: container,
                                                        valueKey: .value,
                                                        valueTypeKey: .value_type)
    }
    
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(layer_input_coordinate, forKey: .layer_input_coordinate)
        try Step_V0.PortValue.encodeFromAI(container: &container,
                                           portValue: self.value,
                                           valueKey: .value,
                                           valueTypeKey: .value_type)
    }
}

// TODO: move
extension Step_V0.PortValue {
    static func decodeFromAI<CodingKeys: CodingKey>(container: KeyedDecodingContainer<CodingKeys>,
                                                    valueKey: CodingKeys,
                                                    valueTypeKey: CodingKeys) throws -> Step_V0.PortValue {
        let nodeTypeString = try container.decode(String.self, forKey: valueTypeKey)
        
        guard let nodeType = Step_V0.NodeType(llmString: nodeTypeString) else {
            throw StitchAIParsingError.nodeTypeParsing(nodeTypeString)
        }
        
        // Parse value given node type
        let portValueType = nodeType.portValueTypeForStitchAI
        
        let decodedValue = try container
            .decodeIfPresentSitchAI(portValueType, forKey: valueKey)
        
        let value = try nodeType.coerceToPortValueForStitchAI(from: decodedValue)
        return value
    }
    
    static func encodeFromAI<CodingKeys: CodingKey>(container: inout KeyedEncodingContainer<CodingKeys>,
                                                    portValue: Step_V0.PortValue,
                                                    valueKey: CodingKeys,
                                                    valueTypeKey: CodingKeys) throws {
        try container.encode(portValue.anyCodable, forKey: valueKey)
        try container.encode(portValue.nodeType, forKey: valueTypeKey)
    }
}

extension Array where Element == CurrentAIPatchBuilderResponseFormat.LayerData {
    var allNestedCustomInputValues: [AIPatchBuilderResponseFormat_V0.CustomLayerInputValue] {
        self.flatMap {
            $0.custom_layer_input_values +
            ($0.children?.allNestedCustomInputValues ?? [])
        }
    }
}

extension AIPatchBuilderResponseFormat_V0.LayerData {
    func createSidebarLayerData(idMap: [UUID : UUID]) throws -> SidebarLayerData {
        guard let newId = idMap.get(self.node_id.value) else {
            throw AIPatchBuilderRequestError.nodeIdNotFound
        }
        
        let children = try self.children?.map {
            try $0.createSidebarLayerData(idMap: idMap)
        }
        
        return SidebarLayerData(id: newId,
                                children: children)
    }
}
