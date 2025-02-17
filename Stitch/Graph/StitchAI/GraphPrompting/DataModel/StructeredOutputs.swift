//
//  StructeredOutputs.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/16/25.
//

import SwiftUI
import StitchSchemaKit
import SwiftyJSON

//extension StitchAIManager {
//    static func createStructeredOutputs() -> StitchAIStructeredOutputsWrapper {
//        
//    }
//}


struct StitchAIStructeredOutputsWrapper: Encodable {
    var defs: [StitchAIStructeredOutputs]
}

struct StitchAIStructeredOutputs: Encodable {
    var AddNodeAction: StepStructeredOutputs
    
    init() {
        self.AddNodeAction = StepStructeredOutputs(StepActionAddNode.self)
    }
}

struct StepStructeredOutputs: OpenAISchemaCustomizable {
    var properties: StitchAIStepSchema?
    var schema: OpenAISchema
    
    init<T>(_ stepActionType: T) where T: StepActionable {
        self.properties = T.createStructeredOutputs()
        
        
    }
    
    init(properties: StitchAIStepSchema?, schema: OpenAISchema) {
        self.properties = properties
        self.schema = schema
    }
}

struct StitchAIStepSchema: Encodable {
    var stepType: StepType
    var nodeId: OpenAISchema? = nil
    var nodeName: OpenAISchemaRef? = nil
    var port: OpenAIGeneric? = nil
    var fromPort: OpenAISchema? = nil
    var fromNodeId: OpenAISchema? = nil
    var toNodeId: OpenAISchema? = nil
    var value: OpenAIGeneric? = nil
    var valueType: OpenAISchemaRef? = nil
    
    func encode(to encoder: Encoder) throws {
        // Reuses coding keys from Step struct
        var container = encoder.container(keyedBy: Step.CodingKeys.self)
        
        let stepTypeSchema = OpenAISchema(type: .string,
                                          const: self.stepType.rawValue)
        
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

protocol OpenAISchemaCustomizable: Encodable {
    associatedtype PropertiesType: Encodable
    
    var properties: PropertiesType? { get set }
    var schema: OpenAISchema { get set }
    
    init(properties: Self.PropertiesType?,
         schema: OpenAISchema)
}

extension OpenAISchemaCustomizable {
    init(type: OpenAISchemaType,
         properties: Self.PropertiesType,
         const: String? = nil,
         required: [String]? = nil,
         additionalPropertes: Bool? = nil) {
        let schema = OpenAISchema(type: type,
                                  const: const,
                                  required: required,
                                  additionalPropertes: additionalPropertes)
        self.init(properties: properties,
                  schema: schema)
    }
}

enum OpenAISchemaCustomizableCodingKeys: String, CodingKey {
    case properties
}

extension OpenAISchemaCustomizable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OpenAISchemaCustomizableCodingKeys.self)
        try container.encodeIfPresent(self.properties, forKey: .properties)
        
        // Encode schema in this JSON using its coding keys
        try self.schema.encode(to: encoder)
    }
}

struct OpenAISchema {
    var type: OpenAISchemaType
    var const: String? = nil
    var required: [String]? = nil
    var additionalPropertes: Bool? = nil
}

extension OpenAISchema: Encodable {
    enum CodingKeys: String, CodingKey {
        case type
        case const
        case required
        case additionalPropertes
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encodeIfPresent(self.const, forKey: .const)
        try container.encodeIfPresent(self.required, forKey: .required)
        try container.encodeIfPresent(self.additionalPropertes, forKey: .additionalPropertes)
    }
}

struct OpenAISchemaRef: Encodable {
    var ref: String
}

struct OpenAIGeneric: Encodable {
    var types: [OpenAISchema]
    var ref: OpenAISchemaRef? = nil
    
    enum CodingKeys: String, CodingKey {
        case anyOf
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var arrayContainer = container.nestedUnkeyedContainer(forKey: .anyOf)
        
        // Add types to array
        for type in self.types {
            try arrayContainer.encode(type)
        }
        
        // Add ref, if exists
        if let ref = self.ref {
            try arrayContainer.encode(ref)
        }
    }
}

enum OpenAISchemaType: String, Encodable {
    case object
    case string
    case number
    case integer
    case boolean
}
