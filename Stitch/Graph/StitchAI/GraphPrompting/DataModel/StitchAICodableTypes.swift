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

// TODO: will delete below when LLM is more reliable at producing number types when expected.

struct StitchAINumber: StitchAIStringConvertable {
    var value: Double
}

struct StitchAIUUID: StitchAIStringConvertable {
    var value: UUID
}

extension UUID: LosslessStringConvertible {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}

typealias StitchAIValueStringConvertable = Codable & CustomStringConvertible & LosslessStringConvertible & Hashable

//extension StitchAIStringConvertable {
//    init(_ value: T) {
//        self.value =
//    }
//}

protocol StitchAIStringConvertable: Codable, Hashable {
    associatedtype T: StitchAIValueStringConvertable
    
    var value: T { get set }
    
    init(value: T)
}


extension StitchAIStringConvertable {
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
            log("StringOrNumber: Decoder: tried double")
            self.init(value: value)
        } else if let stringValue = try? container.decode(String.self),
                  let valueFromString = Self.T(stringValue) {
            log("StringOrNumber: Decoder: tried string")
            self.init(value: valueFromString)
        } else if let jsonValue = try? container.decode(JSON.self),
                  let valueFromJson = Self.T(jsonValue.description) {
            log("StringOrNumber: Decoder: had json \(jsonValue)")
            self.init(value: valueFromJson)
        } else {
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Unexpected type for \(Self.T.self)"
                )
            )
        }
    }
}
