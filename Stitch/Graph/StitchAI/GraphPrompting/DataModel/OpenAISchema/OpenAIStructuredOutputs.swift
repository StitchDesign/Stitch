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
         additionalProperties: Bool? = false) {
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
    associatedtype Schema: OpenAISchemaCustomizable
    
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
    var const: String? = nil
    var required: [String]? = nil
    var additionalProperties: Bool? = nil
    var title: String? = nil
    var description: String? = nil
    var items: OpenAIGeneric? = nil
    var properties: [String: OpenAISchema]? = nil
    var discriminator: OpenAIDiscriminator? = nil
}

struct OpenAIDiscriminator: Encodable {
    var propertyName: String
    
    enum CodingKeys: String, CodingKey {
        case propertyName
    }
}

extension OpenAISchema: Encodable {
    enum CodingKeys: String, CodingKey {
        case type
        case title
        case description
        case const
        case required
        case additionalProperties
        case items
        case properties
        case discriminator
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encodeIfPresent(self.description, forKey: .description)
        try container.encodeIfPresent(self.const, forKey: .const)
        try container.encodeIfPresent(self.required, forKey: .required)
        try container.encodeIfPresent(self.additionalProperties, forKey: .additionalProperties)
        try container.encodeIfPresent(self.items, forKey: .items)
        try container.encodeIfPresent(self.title, forKey: .title)
        try container.encodeIfPresent(self.properties, forKey: .properties)
        try container.encodeIfPresent(self.discriminator, forKey: .discriminator)
    }
}

struct OpenAISchemaEnum: Encodable {
    var values: [String]
    var description: String
    
    enum CodingKeys: String, CodingKey {
        case type
        case enumType = "enum"
        case description
        case additionalProperties
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(OpenAISchemaType.string, forKey: .type)
        try container.encode(self.values, forKey: .enumType)
        try container.encode(self.description, forKey: .description)
        try container.encode(false, forKey: .additionalProperties)
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

struct OpenAIGeneric: Encodable {
    var types: [OpenAISchema] = []
    var refs: [OpenAISchemaRef] = []
    
    enum CodingKeys: String, CodingKey {
        case type
        case items
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(OpenAISchemaType.array, forKey: .type)
        
        // If we have refs, use those
        if !refs.isEmpty {
            try container.encode(refs[0], forKey: .items)
        }
        // Otherwise use the first type
        else if !types.isEmpty {
            try container.encode(types[0], forKey: .items)
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
