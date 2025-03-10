//
//  StructuredOutputs.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/16/25.
//

import SwiftUI
import StitchSchemaKit
import SwiftyJSON

extension StitchAIManager {
    static let structuredOutputs = StitchAIStructuredOutputsPayload()
}

struct StitchAIStructuredOutputsPayload: OpenAISchemaDefinable {
    var defs = StitchAIStructuredOutputsDefinitions()
    var schema = StitchAIStructuredOutputsSchema()
}

struct StitchAIStructuredOutputsSchema: OpenAISchemaCustomizable {
    static let title = "VisualProgrammingActions"
    
    var properties = StitchAIStepsSchema()
    
    var schema = OpenAISchema(type: .object,
                              required: ["steps"],
                              additionalProperties: false,
                              title: Self.title,
                              description: "Strictly follow the action sequence: 1. ADD_NODE, 2. CHANGE_VALUE_TYPE, 3. SET_INPUT, 4. CONNECT_NODES")
}

struct StitchAIStructuredOutputsDefinitions: Encodable {
    // Step actions
    let AddNodeAction = StepStructuredOutputs(StepActionAddNode.self)
    let ConnectNodesAction = StepStructuredOutputs(StepActionConnectionAdded.self)
//    let ChangeValueTypeAction = StepStructuredOutputs(StepActionChangeValueType.self)
    let SetInputAction = StepStructuredOutputs(StepActionSetInput.self)
 
    // Types
    let NodeID = OpenAISchema(type: .string,
                              additionalProperties: false,
                              description: "The unique identifier for the node (UUID)")
 
    let NodeName = OpenAISchemaEnum(values: NodeKind.getAiNodeDescriptions().map(\.nodeKind), description: "The type of node to be created")
 
    let ValueType = OpenAISchemaEnum(values: NodeType.allCases
        .filter { $0 != .none }
        .map { $0.asLLMStepNodeType }, description: "The type of value for the node")
 
    let LayerPorts = OpenAISchemaEnum(values: LayerInputPort.allCases
        .map { $0.asLLMStepPort }, description: "The available ports for layer connections")
 
    // Schema definitions for value types
    let NumberSchema = OpenAISchema(type: .number,
                                   additionalProperties: false,
                                   description: "A numeric value")
 
    let StringSchema = OpenAISchema(type: .string,
                                    additionalProperties: false,
                                    description: "A text value")
 
    let BooleanSchema = OpenAISchema(type: .boolean,
                                     additionalProperties: false,
                                     description: "A boolean value")
 
    let ObjectSchema = OpenAISchema(type: .object,
                                    required: [], additionalProperties: false,
                                    description: "A JSON object value",
                                    properties: [:]
)

}

struct StitchAIStepsSchema: Encodable {
    let steps = OpenAISchema(type: .array,
                             additionalProperties: false,
                             description: "The actions taken to create a graph",
                             items: OpenAIGeneric(types: [],
                                                refs: [
                                                    OpenAISchemaRef(ref: "AddNodeAction"),
                                                    OpenAISchemaRef(ref: "ConnectNodesAction"),
                                                    OpenAISchemaRef(ref: "ChangeValueTypeAction"),
                                                    OpenAISchemaRef(ref: "SetInputAction")
                                                ])
    )
}

struct StepStructuredOutputs: OpenAISchemaCustomizable {
    var properties: StitchAIStepSchema
    var schema: OpenAISchema
    
    init<T>(_ stepActionType: T.Type) where T: StepActionable {
        let requiredProps = T.structuredOutputsCodingKeys.map { $0.rawValue }
        
        self.properties = T.createStructuredOutputs()
        self.schema = .init(type: .object,
                            required: requiredProps,
                            additionalProperties: false)
    }
    
    init(properties: StitchAIStepSchema,
         schema: OpenAISchema) {
        self.properties = properties
        self.schema = schema
    }
}

struct StitchAIStepSchema: Encodable {
    var stepType: StepType
    var nodeId: OpenAISchema? = nil
    var nodeName: OpenAISchemaRef? = nil
    var port: OpenAISchemaRef? = nil
    var fromPort: OpenAISchema? = nil
    var fromNodeId: OpenAISchema? = nil
    var toNodeId: OpenAISchema? = nil
    var value: OpenAIGeneric? = nil
    var valueType: OpenAISchemaRef? = nil
    
    func encode(to encoder: Encoder) throws {
        // Reuses coding keys from Step struct
        var container = encoder.container(keyedBy: Step.CodingKeys.self)
        
        let stepTypeSchema = OpenAISchema(type: .string,
                                          const: self.stepType.rawValue,
                                          additionalProperties: false)
        
        try container.encode(stepTypeSchema, forKey: .stepType)
        try container.encodeIfPresent(nodeId, forKey: .nodeId)
        try container.encodeIfPresent(nodeName, forKey: .nodeName)
        try container.encodeIfPresent(port, forKey: .port)
        try container.encodeIfPresent(fromPort, forKey: .fromPort)
        try container.encodeIfPresent(fromNodeId, forKey: .fromNodeId)
        try container.encodeIfPresent(toNodeId, forKey: .toNodeId)
        try container.encodeIfPresent(value, forKey: .value)
        try container.encodeIfPresent(valueType, forKey: .valueType)
    }
}
