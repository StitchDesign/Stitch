//
//  StitchAICodableTypes.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/7/25.
//

import SwiftUI
import StitchSchemaKit
import SwiftyJSON

/**
 Saves JSON-friendly versions of data structures saved in `PortValue`.
 */

struct StitchAIPosition: Codable {
    var x: Double
    var y: Double
}

struct StitchAISize: Codable {
    var width: StitchAISizeDimension
    var height: StitchAISizeDimension
    
//    func decode(_ decoder: Decoder) throws -> Self {
//        
//    }
}

// TODO: will delete below when LLM is more reliable at producing number types when expected.

struct StitchAIInt: StitchAIPrimitiveStringConvertable {
    var value: Int
}

struct StitchAINumber: StitchAIPrimitiveStringConvertable {
    var value: Double
}

struct StitchAIUUID: StitchAIPrimitiveStringConvertable {
    var value: UUID
}

extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}

struct StitchAISizeDimension: StitchAIPrimitiveStringConvertable {
    var value: LayerDimension
}

extension LayerDimension: LosslessStringConvertible {
    public init?(_ description: String) {
        guard let result = Self.fromUserEdit(edit: description) else {
            return nil
        }
        
        self = result
    }
}

typealias StitchAIValueStringConvertable = Codable & CustomStringConvertible & LosslessStringConvertible & Hashable

protocol StitchAIStringConvertable: Hashable {
    associatedtype T: StitchAIValueStringConvertable
    
    var value: T { get set }
    
    init(value: T)
}

protocol StitchAIPrimitiveStringConvertable: Codable, StitchAIStringConvertable { }
//protocol StitchAICustomStringConvertable: Codable, StitchAIStringConvertable { }

extension StitchAIPrimitiveStringConvertable {
    init?(value: T?) {
        guard let value = value else {
            return nil
        }
        
        self.init(value: value)
    }
    
    /// Encodes the value as a string
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        // LLM expects string type
        try container.encode(self.value.description)
    }
    
    /// Decodes a value that could be string, int, double, or JSON
    /// - Parameter decoder: The decoder to read from
    /// - Throws: DecodingError if value cannot be converted to string
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding as different types, converting each to string
        if let value = try? container.decode(Self.T.self) {
            log("StitchAIStringConvertable: Decoder: tried double")
            self.init(value: value)
        } else if let stringValue = try? container.decode(String.self),
                  let valueFromString = Self.T(stringValue) {
            log("StitchAIStringConvertable: Decoder: tried string")
            self.init(value: valueFromString)
        } else if let jsonValue = try? container.decode(JSON.self),
                  let valueFromJson = Self.T(jsonValue.description) {
            log("StitchAIStringConvertable: Decoder: had json \(jsonValue)")
            self.init(value: valueFromJson)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "StitchAIStringConvertable: unexpected type for \(Self.T.self)"
                )
            )
        }
    }
}

//enum StitchAICustomStringConvertableCodingKeys: String, CodingKey {
//    case value
//}
//
//extension StitchAICustomStringConvertable {
//    init?(value: T?) {
//        guard let value = value else {
//            return nil
//        }
//        
//        self.init(value: value)
//    }
//    
//    /// Encodes the value as a string
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: StitchAICustomStringConvertableCodingKeys.self)
//        
//        // LLM expects string type
//        try container.encode(self.value.description,
//                             forKey: .value)
//    }
//    
//    /// Decodes a value that could be string, int, double, or JSON
//    /// - Parameter decoder: The decoder to read from
//    /// - Throws: DecodingError if value cannot be converted to string
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: StitchAICustomStringConvertableCodingKeys.self)
//        
//        // Try decoding as different types, converting each to string
//        if let value = try? container.decode(Self.T.self,
//                                             forKey: .value) {
//            log("StitchAIStringConvertable: Decoder: tried double")
//            self.init(value: value)
//        } else if let stringValue = try? container.decode(String.self,
//                                                          forKey: .value),
//                  let valueFromString = Self.T(stringValue) {
//            log("StitchAIStringConvertable: Decoder: tried string")
//            self.init(value: valueFromString)
//        } else if let jsonValue = try? container.decode(JSON.self,
//                                                        forKey: .value),
//                  let valueFromJson = Self.T(jsonValue.description) {
//            log("StitchAIStringConvertable: Decoder: had json \(jsonValue)")
//            self.init(value: valueFromJson)
//        } else {
//            throw DecodingError.typeMismatch(
//                String.self,
//                DecodingError.Context(
//                    codingPath: decoder.codingPath,
//                    debugDescription: "StitchAIStringConvertable: unexpected type for \(Self.T.self)"
//                )
//            )
//        }
//    }
//}
