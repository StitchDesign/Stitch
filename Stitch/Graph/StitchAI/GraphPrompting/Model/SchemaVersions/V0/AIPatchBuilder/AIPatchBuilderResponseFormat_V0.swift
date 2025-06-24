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
        let name = "PatchBuilder"
        let schema = PatchBuilderStructuredOutputsPayload()
    }
    
    struct PatchBuilderStructuredOutputsPayload: OpenAISchemaDefinable {
        let defs = PatchBuilderStructuredOutputsDefinitions()
        let schema = OpenAISchema(type: .object,
                                  properties: AIPatchBuilderResponseFormat_V0.GraphBuilderSchema(),
                                  required: ["patches", "patch_connections", "layer_connections", "custom_input_values"])
        let strict = true
    }

    struct PatchBuilderStructuredOutputsDefinitions: Encodable {
        // Types
        let ValueType = OpenAISchemaEnum(values: Step_V0.NodeType.allCases
            .filter { $0 != .none }
            .map { $0.asLLMStepNodeType }
        )
        
        let LayerPorts = OpenAISchemaEnum(values: Step_V0.LayerInputPort.allCases
            .map { $0.asLLMStepPort }
        )
    }
    
    struct GraphBuilderSchema: Encodable {
        static let nodeIndexedCoordinateSchema = OpenAISchema(
            type: .object,
            properties: NodeIndexedCoordinateSchema(),
            required: ["node_id", "port_index"])
        
        let patches = OpenAISchema(
            type: .array,
            required: ["id", "suggested_title", "javascript_source_code", "input_definitions", "output_definitions"],
            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.PatchNodeSchema()])
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

    struct PatchNodeSchema: Encodable {
        static let portDefinitions = AIEditJsNodeResponseFormat_V0.JsNodeSettingsSchema.portDefinitions
        
        let id = OpenAISchema(type: .string)
        let suggested_title = OpenAISchema(type: .string)
        let javascript_source_code = OpenAISchema(type: .string)
        let input_definitions = Self.portDefinitions
        let output_definitions = Self.portDefinitions
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
        let patches: [AIPatchBuilderResponseFormat_V0.PatchNode]
//        let layers: [Self.LayerNode]
        let patch_connections: [PatchConnection]
        let layer_connections: [LayerConnection]
        let custom_patch_input_values: [CustomPatchInputValue]
    }
    
    struct PatchNode: Codable {
        let id: UUID
        let javascript_source_code: String
        let suggested_title: String
        let input_definitions: [JavaScriptPortDefinitionAI_V0.JavaScriptPortDefinitionAI]
        let output_definitions: [JavaScriptPortDefinitionAI_V0.JavaScriptPortDefinitionAI]
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
        let layer_id: UUID
        let input_port_type: LayerInputPort_V31.LayerInputPort
    }

    struct NodeIndexedCoordinate: Codable {
        let node_id: UUID
        let port_index: Int
    }
    
    struct CustomPatchInputValue: Codable {
        let patch_input_coordinate: NodeIndexedCoordinate
        let value: PortValue
    }
}
