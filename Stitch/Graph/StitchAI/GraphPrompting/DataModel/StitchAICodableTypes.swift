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
}


// TODO: will delete below when LLM is more reliable at producing number types when expected.

struct StitchAIColor: StitchAIStringConvertable {
    var value: Color
}

struct StitchAIInt: StitchAIStringConvertable {
    var value: Int
}

struct StitchAINumber: StitchAIStringConvertable {
    var value: Double
}

struct StitchAIUUID: StitchAIStringConvertable {
    var value: UUID
}

extension UUID: StitchAIValueStringConvertable {
    public init?(_ description: String) {
        self.init(uuidString: description)
    }
}

extension Int: StitchAIValueStringConvertable { }
extension Double: StitchAIValueStringConvertable { }

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

struct StitchAISizeDimension: StitchAIStringConvertable {
    var value: LayerDimension
}

extension LayerDimension: StitchAIValueStringConvertable {
    public init?(_ description: String) {
        guard let result = Self.fromUserEdit(edit: description) else {
            return nil
        }
        
        self = result
    }
}

protocol StitchAIValueStringConvertable: Codable, CustomStringConvertible, LosslessStringConvertible, Hashable {
    var encodableString: String { get }
}

extension StitchAIValueStringConvertable {
    // Provides default value but can be overwritten.
    var encodableString: String {
        self.description
    }
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
        
        // LLM expects string type
        try container.encode(self.value.encodableString)
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
