//
//  OpenAIStructuredOutputs.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/17/25.
//

import SwiftUI

protocol OpenAISchemaCustomizable: Encodable {
    associatedtype PropertiesType: Encodable
    
    var properties: PropertiesType { get set }
    var schema: OpenAISchema { get set }
    
    init(properties: Self.PropertiesType,
         schema: OpenAISchema)
}

extension OpenAISchemaCustomizable {
    init(type: OpenAISchemaType,
         properties: Self.PropertiesType,
         const: String? = nil,
         required: [String]? = nil,
         additionalProperties: Bool? = nil) {
        let schema = OpenAISchema(type: type,
                                  const: const,
                                  required: required,
                                  additionalProperties: additionalProperties)
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

protocol OpenAISchemaDefinable: Encodable {
    associatedtype Defs: Encodable
    associatedtype Schema: Encodable
    
    var defs: Defs { get }
    
    var schema: Schema { get }
}

enum OpenAISchemaDefinableCodingKeys: String, CodingKey {
    case defs = "$defs"
}

extension OpenAISchemaDefinable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: OpenAISchemaDefinableCodingKeys.self)
        try container.encode(self.defs, forKey: .defs)
        
        try self.schema.encode(to: encoder)
    }
}

struct OpenAISchema {
    var type: OpenAISchemaType
    var properties: (any Encodable & Sendable)?
    var const: String? = nil
    var required: [String]? = nil
    var additionalProperties: Bool? = nil
    var title: String? = nil
    var description: String? = nil
    var items: OpenAIGeneric? = nil
}

extension OpenAISchema: Encodable, Sendable {
    enum CodingKeys: String, CodingKey {
        case type
        case title
        case description
        case const
        case required
        case additionalProperties
        case items
        case properties
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try self.encode(to: encoder, container: &container)
    }
    
    func encode(to encoder: Encoder,
                container: inout KeyedEncodingContainer<OpenAISchema.CodingKeys>) throws {
        try container.encode(self.type, forKey: .type)
        try container.encodeIfPresent(self.description, forKey: .description)
        try container.encodeIfPresent(self.const, forKey: .const)
        try container.encodeIfPresent(self.required, forKey: .required)
        try container.encodeIfPresent(self.additionalProperties, forKey: .additionalProperties)
        try container.encodeIfPresent(self.items, forKey: .items)
        try container.encodeIfPresent(self.title, forKey: .title)
        
        // Conditional encoding for generic
        if let properties = self.properties {
            try self.properties?.encode(to: container.superEncoder(forKey: .properties))
        }
    }
}

struct OpenAISchemaEnum: Encodable {
    var values: [String]
    
    enum CodingKeys: String, CodingKey {
        case type
        case enumType = "enum"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(OpenAISchemaType.string, forKey: .type)
        try container.encode(self.values, forKey: .enumType)
    }
}

struct OpenAISchemaRef: Encodable {
    var ref: String
    
    enum CodingKeys: String, CodingKey {
        case ref = "$ref"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let path = "#/$defs/\(self.ref)"
        
        try container.encode(path, forKey: .ref)
    }
}

struct OpenAIGeneric: Encodable, Sendable {
    var types: [any Encodable & Sendable] = []
    var refs: [OpenAISchemaRef] = []
    
    enum CodingKeys: String, CodingKey {
        case anyOf
    }
    
    func encode(to encoder: Encoder) throws {
        // Specify generic "anyOf" property if multiple types
        let isGeneric = types.count + refs.count > 1
        
        if isGeneric {
            var container = encoder.container(keyedBy: CodingKeys.self)
            var unkeyedContainer = container.nestedUnkeyedContainer(forKey: .anyOf)
            
            // Add types to array
            for type in self.types {
                try unkeyedContainer.encode(type)
            }
            
            // Add refs to array
            for ref in self.refs {
                try unkeyedContainer.encode(ref)
            }
        }
        
        else {
            var container = encoder.singleValueContainer()
            
            // Add types to array
            for type in self.types {
                try container.encode(type)
            }
            
            // Add refs to array
            for ref in self.refs {
                try container.encode(ref)
            }
        }
    }
}

enum OpenAISchemaType: String, Encodable {
    case object
    case string
    case number
    case integer
    case boolean
    case array
}
