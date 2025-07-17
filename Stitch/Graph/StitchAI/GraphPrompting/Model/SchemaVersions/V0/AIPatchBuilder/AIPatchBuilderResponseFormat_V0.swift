//
//  AIPatchBuilderResponseFormat_V).swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIRequestBuilder_V0 {
    static let codeBuilderFunction = OpenAIFunction(
        name: "create_swiftui_code",
        description: "Generate SwiftUI code from Stitch concepts.",
        parameters: OpenAISchema(
            type: .object,
            properties: SourceCodeResponseSchema(),
            required: ["source_code"],
            description: "SwiftUI source code."),
        strict: true
    )
    
    static let codeEditorFunction = OpenAIFunction(
        name: "edit_swiftui_code",
        description: "Edit SwiftUI code based on user prompt.",
        parameters: OpenAISchema(
            type: .object,
            properties: SourceCodeResponseSchema(),
            required: ["source_code"],
            description: "SwiftUI source code."),
        strict: true
    )
    
    struct SourceCodeResponseSchema: Encodable {
        let source_code = OpenAISchema(
            type: .string,
            description: "SwiftUI source code.")
    }
    
    struct SourceCodeResponse: Codable {
        let source_code: String
    }
}

/// Only used for supplying graph data for edit scenarios.
enum AIGraphDataSchema_V0 {
    struct AIGraphDataSchemaWrapper: OpenAISchemaDefinable {
        let defs = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions()
        let schema = OpenAISchema(type: .object,
                                  properties: AIGraphDataSchema(),
                                  required: ["layer_data_list", "patch_data"])
    }
    
    struct AIGraphDataSchema: Encodable {
        let layer_data_list = OpenAISchemaRef(ref: "LayerNodes")
        let patch_data = OpenAISchemaRef(ref: "PatchData")
    }
}

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
                                  required: ["javascript_patches", "native_patches", "native_patch_value_type_settings", "patch_connections", "layer_connections", "custom_patch_input_values"])
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
        
        let PatchData = OpenAISchema(type: .object,
                                     properties: AIPatchBuilderResponseFormat_V0.GraphBuilderSchema(),
                                     required: ["javascript_patches", "native_patches", "native_patch_value_type_settings", "patch_connections", "layer_connections", "custom_patch_input_values"])
        
        let LayerNodes = OpenAISchema(
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
        
        let native_patch_value_type_settings = OpenAISchema(
            type: .array,
            required: ["node_id", "value_type"],
            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.NativePatchNodeValueSettingSchema()])
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
        let children = OpenAISchemaRef(ref: "LayerNodes")
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
    
    struct NativePatchNodeValueSettingSchema: Encodable {
        let node_id = OpenAISchema(type: .string)
        let value_type = OpenAISchemaRef(ref: "ValueType")
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
