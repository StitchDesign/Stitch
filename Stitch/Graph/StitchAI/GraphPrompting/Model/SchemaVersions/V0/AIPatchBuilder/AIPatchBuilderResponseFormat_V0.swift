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
                                  required: ["layers", "javascript_patches", "native_patches", "patch_connections", "layer_connections", "custom_input_values"])
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
            required: ["node_id", "node_name"],
            description: "A nested list of layer nodes to be created in the graph.",
            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.LayerNodeSchema()])
        )
    }
    
    struct GraphBuilderSchema: Encodable {
        static let nodeIndexedCoordinateSchema = OpenAISchema(
            type: .object,
            properties: NodeIndexedCoordinateSchema(),
            required: ["node_id", "port_index"])
        
        let layers = OpenAISchemaRef(ref: "Layer_Nodes")
        
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
    
    struct LayerNodeSchema: Encodable {
        let node_id = OpenAISchema(type: .string)
        let suggested_title = OpenAISchema(type: .string)
        let node_name = OpenAISchemaRef(ref: "NodeName")
        let children = OpenAISchemaRef(ref: "Layer_Nodes")
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
        let src_port = AIPatchBuilderResponseFormat_V0.GraphBuilderSchema.nodeIndexedCoordinateSchema
        let dest_port = AIPatchBuilderResponseFormat_V0.GraphBuilderSchema.nodeIndexedCoordinateSchema
    }
    
    struct LayerConnectionSchema: Encodable {
        let src_port = AIPatchBuilderResponseFormat_V0.GraphBuilderSchema.nodeIndexedCoordinateSchema
        let dest_port = OpenAISchema(
            type: .object,
            properties: LayerInputCoordinateSchema(),
            required: ["layer_id", "input_port_type"])
    }
    
    struct CustomPatchInputValueSchema: Encodable {
        let patch_input_coordinate = AIPatchBuilderResponseFormat_V0.GraphBuilderSchema.nodeIndexedCoordinateSchema
        
        let value = OpenAIGeneric(types: [
            OpenAISchema(type: .number),
            OpenAISchema(type: .string),
            OpenAISchema(type: .boolean),
            OpenAISchema(type: .object, additionalProperties: false)
          ])
        
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
        let layers: [AIPatchBuilderResponseFormat_V0.LayerNode]
        let javascript_patches: [AIPatchBuilderResponseFormat_V0.JsPatchNode]
        let native_patches: [AIPatchBuilderResponseFormat_V0.NativePatchNode]
//        let layers: [Self.LayerNode]
        let patch_connections: [PatchConnection]
        let layer_connections: [LayerConnection]
        let custom_patch_input_values: [CustomPatchInputValue]
    }
    
    struct LayerNode: Codable {
        let node_id: StitchAIUUID_V0.StitchAIUUID
        var suggested_title: String?
        let node_name: StitchAIPatchOrLayer
        var children: [LayerNode]?
        
        enum CodingKeys: String, CodingKey {
            case node_id
            case suggested_title
            case node_name
            case children
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(node_id, forKey: .node_id)
            try container.encode(node_name, forKey: .node_name)
            
            try container.encodeIfPresent(suggested_title, forKey: .suggested_title)

            // Only encode children if group layer
            try container.encodeIfPresent(children, forKey: .children)
        }
        
        init(from decoder: any Decoder) throws {
            var container = try decoder.container(keyedBy: CodingKeys.self)
            node_id = try container.decode(StitchAIUUID_V0.StitchAIUUID.self, forKey: .node_id)
            suggested_title = try container.decodeIfPresent(String.self, forKey: .suggested_title)
            node_name = try container.decode(StitchAIPatchOrLayer.self, forKey: .node_name)
            
            if let children = try container.decodeIfPresent([LayerNode].self, forKey: .children) {
                self.children = children
            } else {
                // Make sure we have an empty list if layer is a group
                if node_name.value == .layer(.group) || node_name.value == .layer(.realityView) {
                    self.children = []
                }
            }
        }
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
