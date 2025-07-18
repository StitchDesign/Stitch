//
//  AIPatchBuilderResponseFormat_V).swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

import SwiftUI
import StitchSchemaKit


enum StitchAIRequestBuilder_V0 {
    enum StitchAIRequestBuilderFunctions: String, CaseIterable {
        case codeBuilder = "create_swiftui_code"
        case codeEditor = "edit_swiftui_code"
        case patchBuilder = "patch_builder"
    }
}

extension StitchAIRequestBuilder_V0.StitchAIRequestBuilderFunctions {
    static let allFunctions: [OpenAIFunction] = Self.allCases.map(\.function)
    
    var function: OpenAIFunction {
        switch self {
        case .codeBuilder:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Generate SwiftUI code from Stitch concepts.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: StitchAIRequestBuilder_V0.SourceCodeResponseSchema(),
                    required: ["source_code"],
                    description: "SwiftUI source code."),
                strict: true
            )
        
        case .codeEditor:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Edit SwiftUI code based on user prompt.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: StitchAIRequestBuilder_V0.SourceCodeResponseSchema(),
                    required: ["source_code"],
                    description: "SwiftUI source code."),
                strict: true
            )
            
        case .patchBuilder:
            return OpenAIFunction(
                name: self.rawValue,
                description: "Build Stitch graphs based on layer data and SwiftUI source code.",
                parameters: OpenAISchema(
                    type: .object,
                    properties: AIPatchBuilderResponseFormat_V0.GraphBuilderSchema(),
                    required: ["javascript_patches", "native_patches", "native_patch_value_type_settings", "patch_connections", "layer_connections", "custom_patch_input_values"],
                    description: "Patch data for a Stitch graph."),
                strict: false
            )
        }
    }
}

extension StitchAIRequestBuilder_V0 {
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
//enum AIGraphDataSchema_V0 {
//    struct AIGraphDataSchemaWrapper: OpenAISchemaDefinable {
//        let defs = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions()
//        let schema = OpenAISchema(type: .object,
//                                  properties: AIGraphDataSchema(),
//                                  required: ["layer_data_list", "patch_data"])
//    }
    
//    struct AIGraphDataSchema: Encodable {
//        let layer_data_list = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.LayerNodes
//        let patch_data = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.PatchData
//    }
//}

enum AIPatchBuilderResponseFormat_V0 {
    
    
    // TODO: remove this
//    struct AIPatchBuilderResponseFormat: OpenAIResponseFormatable {
//        let type = "json_schema"
//        let json_schema = AIPatchBuilderJsonSchema()
//    }
//
//    
//    
//    struct AIPatchBuilderJsonSchema: OpenAIJsonSchema {
//        let name = "GraphBuilder"
//        let schema = PatchBuilderStructuredOutputsPayload()
//    }
//    
//    struct PatchBuilderStructuredOutputsPayload: OpenAISchemaDefinable {
//        let defs = PatchBuilderStructuredOutputsDefinitions()
//        let schema = OpenAISchema(type: .object,
//                                  properties: AIPatchBuilderResponseFormat_V0.GraphBuilderSchema(),
//                                  required: ["javascript_patches", "native_patches", "native_patch_value_type_settings", "patch_connections", "layer_connections", "custom_patch_input_values"])
//        let strict = true
//    }

    struct PatchBuilderStructuredOutputsDefinitions: Encodable {
        // Value Types
        static let ValueType = OpenAISchemaEnum(values: Step_V0.NodeType.allCases
            .filter { $0 != .none }
            .map { $0.asLLMStepNodeType }
        )
        
        // Node Kinds
        static let NodeName = OpenAISchemaEnum(values: Step_V0.NodeKind.getAiNodeDescriptions().map(\.nodeKind))
        
        static let LayerPorts = OpenAISchemaEnum(values: Step_V0.LayerInputPort.allCases
            .map { $0.asLLMStepPort }
        )
        
        static let PatchData = OpenAISchema(type: .object,
                                     properties: AIPatchBuilderResponseFormat_V0.GraphBuilderSchema(),
                                     required: [
                                        "javascript_patches", "native_patches", "native_patch_value_type_settings", "patch_connections", "layer_connections", "custom_patch_input_values"])
        
//        let LayerNodes = OpenAISchema(
//            type: .array,
//            required: ["node_id", "node_name", "custom_layer_input_values"],
//            description: "A nested list of layer nodes to be created in the graph.",
//            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.LayerNodeSchema()])
//        )
        
        static let Values = OpenAIGeneric(
            types: [OpenAISchema(type: .number),
                    OpenAISchema(type: .string),
                    OpenAISchema(type: .boolean),
                    OpenAISchema(type: .object, additionalProperties: true)],
            required: []
        )
        
        static let PatchCoordinate = OpenAISchema(
            type: .object,
            properties: NodeIndexedCoordinateSchema(),
            required: ["node_id", "port_index"])
        
        static let LayerInputCoordinate = OpenAISchema(
            type: .object,
            properties: LayerInputCoordinateSchema(),
            required: ["layer_id", "input_port_type"])
    }
    
    struct GraphBuilderSchema: Encodable {
        let javascript_patches = OpenAISchema(
            type: .array,
            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.JsPatchNodeSchema()],
                                 required: ["node_id", "suggested_title", "javascript_source_code", "input_definitions", "output_definitions"])
        )
        
        let native_patches = OpenAISchema(
            type: .array,
            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.NativePatchNodeSchema()],
                                 required: ["node_id", "node_name"])
        )
        
        let native_patch_value_type_settings = OpenAISchema(
            type: .array,
            items: OpenAIGeneric(types: [AIPatchBuilderResponseFormat_V0.NativePatchNodeValueSettingSchema()],
                                 required: ["node_id", "value_type"])
            )
//        
        let patch_connections = OpenAISchema(
            type: .array,
            items: OpenAIGeneric(
                types: [AIPatchBuilderResponseFormat_V0.PatchConnectionSchema()],
                required: ["src_port", "dest_port"]
            )
        )
        
        let layer_connections = OpenAISchema(
            type: .array,
            items: OpenAIGeneric(
                types: [AIPatchBuilderResponseFormat_V0.LayerConnectionSchema()],
                required: ["src_port", "dest_port"]
            )
        )

        let custom_patch_input_values = OpenAISchema(
            type: .array,
            items: OpenAIGeneric(
                types: [AIPatchBuilderResponseFormat_V0.CustomPatchInputValueSchema()],
                required: ["patch_input_coordinate", "value", "value_type"]
            )
        )
    }
    
    // MARK: not used for outputs, just inputs.
//    struct LayerNodeSchema: Encodable {
//        let node_id = OpenAISchema(type: .string)
//        let suggested_title = OpenAISchema(type: .string)
//        let node_name = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.NodeName
//        let children = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.LayerNodes
//        let custom_layer_input_values = OpenAISchema(
//            type: .array,
//            required: ["layer_input_coordinate", "value", "value_type"],
//            items: OpenAIGeneric(types: [
//                AIPatchBuilderResponseFormat_V0.CustomLayerInputValueSchema()
//            ])
//        )
//    }

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
        let node_name = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.NodeName
    }
    
    struct NativePatchNodeValueSettingSchema: Encodable {
        let node_id = OpenAISchema(type: .string)
        let value_type = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.ValueType
    }
    
    struct PatchConnectionSchema: Encodable {
        let src_port = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.PatchCoordinate
        let dest_port = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.PatchCoordinate
    }
    
    struct LayerConnectionSchema: Encodable {
        let src_port = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.PatchCoordinate
        let dest_port = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.LayerInputCoordinate
    }
    
    struct CustomPatchInputValueSchema: Encodable {
        let patch_input_coordinate = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.PatchCoordinate
        let value = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.Values
        let value_type = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.ValueType
    }
    
    struct CustomLayerInputValueSchema: Encodable {
        let layer_input_coordinate = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.LayerInputCoordinate
        let value = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.Values
        let value_type = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.ValueType
    }
    
    struct NodeIndexedCoordinateSchema: Encodable {
        let node_id = OpenAISchema(type: .string)
        let port_index = OpenAISchema(type: .integer)
    }
    
    struct LayerInputCoordinateSchema: Encodable {
        let layer_id = OpenAISchema(type: .string)
        let input_port_type = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.LayerPorts
    }

    struct PortDefinitionSchema: Encodable {
        let label = OpenAISchema(type: .string)
        let strict_type = AIPatchBuilderResponseFormat_V0.PatchBuilderStructuredOutputsDefinitions.ValueType
    }
}
