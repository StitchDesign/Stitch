//
//  StepTypeDefinitions_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/25.
//

enum StepActionAddNode_V0 {
    struct StepActionAddNode: AIGraphCreationResponseFormat_V0.StructredOutputsGenerable {
        static let stepType: StepType_V0.StepType = .addNode
        static let structuredOutputsCodingKeys: Set<Step_V0.Step.CodingKeys> = [.stepType, .nodeId, .nodeName]
        
        var nodeId: NodeId
        var nodeName: Step_V0.PatchOrLayer
    
        static func createStructuredOutputs() -> AIGraphCreationResponseFormat_V0.AIGraphCreationStepSchema {
            .init(stepType: .addNode,
                  nodeId: OpenAISchema(type: .string),
                  nodeName: OpenAISchemaRef(ref: "NodeName")
            )
        }
    }
}

enum StepActionConnectionAdded_V0 {
    struct StepActionConnectionAdded: AIGraphCreationResponseFormat_V0.StructredOutputsGenerable {
        static let stepType = StepType_V0.StepType.connectNodes
        static let structuredOutputsCodingKeys: Set<Step_V0.Step.CodingKeys> = [.stepType, .port, .fromPort, .fromNodeId, .toNodeId]
        
        // effectively the 'to port'
        let port: Step_V0.NodeIOPortType // integer or key path
        var toNodeId: NodeId
        
        let fromPort: Int //NodeIOPortType // integer or key path
        var fromNodeId: NodeId
        
        static func createStructuredOutputs() -> AIGraphCreationResponseFormat_V0.AIGraphCreationStepSchema {
            .init(stepType: .connectNodes,
                  port: OpenAIGeneric(types: [OpenAISchema(type: .integer)],
                                      refs: [OpenAISchemaRef(ref: "LayerPorts")]),
                  fromPort: OpenAISchema(type: .integer),
                  fromNodeId: OpenAISchema(type: .string),
                  toNodeId: OpenAISchema(type: .string)
            )
        }
    }
}

enum StepActionChangeValueType_V0 {
    struct StepActionChangeValueType: AIGraphCreationResponseFormat_V0.StructredOutputsGenerable {
        static let stepType = StepType_V0.StepType.changeValueType
        static let structuredOutputsCodingKeys: Set<Step_V0.Step.CodingKeys> = [.stepType, .nodeId, .valueType]
        
        var nodeId: NodeId
        var valueType: Step_V0.NodeType
        
        static func createStructuredOutputs() -> AIGraphCreationResponseFormat_V0.AIGraphCreationStepSchema {
            .init(stepType: .changeValueType,
                  nodeId: OpenAISchema(type: .string),
                  valueType: OpenAISchemaRef(ref: "ValueType")
            )
        }
    }
}

enum StepActionSetInput_V0 {
    struct StepActionSetInput: AIGraphCreationResponseFormat_V0.StructredOutputsGenerable {
        static let stepType = StepType_V0.StepType.setInput
        static let structuredOutputsCodingKeys: Set<Step_V0.Step.CodingKeys> = [.stepType, .nodeId, .port, .value, .valueType]
        
        var nodeId: NodeId
        let port: Step_V0.NodeIOPortType // integer or key path
        var value: Step_V0.PortValue
        let valueType: Step_V0.NodeType
        
        static func createStructuredOutputs() -> AIGraphCreationResponseFormat_V0.AIGraphCreationStepSchema {
            .init(stepType: .setInput,
                  nodeId: OpenAISchema(type: .string),
                  port: OpenAIGeneric(types: [OpenAISchema(type: .integer)],
                                      refs: [OpenAISchemaRef(ref: "LayerPorts")]),
                  value: OpenAIGeneric(types: [
                    OpenAISchema(type: .number),
                    OpenAISchema(type: .string),
                    OpenAISchema(type: .boolean),
                    OpenAISchema(type: .object, additionalProperties: false)
                  ]),
                  valueType: OpenAISchemaRef(ref: "ValueType")
            )
        }
    }
}

enum StepActionLayerGroupCreated_V0 {
    struct StepActionLayerGroupCreated: AIGraphCreationResponseFormat_V0.StructredOutputsGenerable {
        static let stepType: StepType_V0.StepType = .sidebarGroupCreated
        static let structuredOutputsCodingKeys: Set<Step_V0.Step.CodingKeys> = [.stepType, .nodeId, .children]
        
        var nodeId: NodeId
        var children: NodeIdSet
    
        static func createStructuredOutputs() -> AIGraphCreationResponseFormat_V0.AIGraphCreationStepSchema {
            .init(stepType: .sidebarGroupCreated,
                  nodeId: OpenAISchema(type: .string),
                  children: OpenAISchemaRef(ref: "NodeIdSet"))
        }
    }
}
