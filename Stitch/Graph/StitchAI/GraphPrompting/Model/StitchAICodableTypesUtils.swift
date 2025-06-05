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

extension UUID: StitchAIValueStringConvertable {
    var encodableString: String {
        self.description
    }
    
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}

extension Color: StitchAIValueStringConvertable {
    var encodableString: String {
        self.asHexDisplay
    }
    
    public init?(_ description: String) {
        guard let color = ColorConversionUtils.hexToColor(description) else {
            return nil
        }
        
        self = color
    }
}

protocol StitchAIValueStringConvertable: Codable, LosslessStringConvertible, Hashable {
    var encodableString: String { get }
}

protocol StitchAIStringConvertable: Codable, Hashable {
    associatedtype T: StitchAIValueStringConvertable
    
    var value: T { get set }
    
    init(value: T)
}

extension StitchAIStringConvertable {
    init?(value: T?) {
        guard let value = value else {
            return nil
        }
        
        self.init(value: value)
    }
    
    /// Encodes the value as a string
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(self.value.encodableString)
    }
    
    /// Decodes a value that could be string, int, double, or JSON
    /// - Parameter decoder: The decoder to read from
    /// - Throws: DecodingError if value cannot be converted to string
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        // Try decoding as different types, converting each to string
        if let value = try? container.decode(Self.T.self) {
//            log("StitchAIStringConvertable: Decoder: tried double")
            self.init(value: value)
        } else if let stringValue = try? container.decode(String.self),
                  let valueFromString = Self.T(stringValue) {
//            log("StitchAIStringConvertable: Decoder: tried string")
            self.init(value: valueFromString)
        } else if let jsonValue = try? container.decode(JSON.self),
                  let valueFromJson = Self.T(jsonValue.description) {
//            log("StitchAIStringConvertable: Decoder: had json \(jsonValue)")
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

extension Encodable {
    /// Re-decodes a function into another type, useful for type conversions when properties are exactly the same. Commonly used for versioned schemas that haven't changed.
    func convert<T>(to type: T.Type) throws -> T where T: Decodable {
        let encoder = getStitchEncoder()
        let decoder = getStitchDecoder()
        
        let data = try encoder.encode(self)
        let convertedType = try decoder.decode(T.self, from: data)
        return convertedType
    }
}
