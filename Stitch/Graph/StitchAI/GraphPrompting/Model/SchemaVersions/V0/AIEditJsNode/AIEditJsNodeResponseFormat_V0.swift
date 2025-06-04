//
//  AIEditJsNodeResponseFormat_V).swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/4/25.
//

enum AIEditJsNodeResponseFormat_V0 {
    struct AIEditJsNodeResponseFormat: OpenAIResponseFormatable {
        let type = "json_schema"
        let json_schema = AIEditJsNodeJsonSchema()
    }

    struct AIEditJsNodeJsonSchema: OpenAIJsonSchema {
        let name = "EditJSNode"
        let schema = EditJsNodeStructuredOutputsPayload()
    }
    
    struct EditJsNodeStructuredOutputsPayload: OpenAISchemaDefinable {
        let defs = EditJsNodeStructuredOutputsDefinitions()
        let schema = OpenAISchema(type: .object,
                                  properties: JsNodeSettingsSchema(),
                                  required: ["script", "input_definitions", "output_definitions"])
        let strict = true
    }

    struct EditJsNodeStructuredOutputsDefinitions: Encodable {
        // Types
        let ValueType = OpenAISchemaEnum(values: StitchAINodeType.allCases
            .filter { $0 != .none }
            .map { $0.asLLMStepNodeType }
        )
    }

    struct JsNodeSettingsSchema: Encodable {
        static let portDefinitions = OpenAISchema(type: .array,
                                                  required: ["label", "strict_type"],
                                                  items: OpenAIGeneric(types: [PortDefinitionSchema()]))
        
        let script = OpenAISchema(type: .string)
        let input_definitions = Self.portDefinitions
        let output_definitions = Self.portDefinitions
    }

    struct PortDefinitionSchema: Encodable {
        let label = OpenAISchema(type: .string)
        let strict_type = OpenAISchemaRef(ref: "ValueType")
    }
}
