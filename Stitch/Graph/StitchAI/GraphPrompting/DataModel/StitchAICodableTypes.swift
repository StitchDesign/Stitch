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


struct StitchAIPoint3D: Codable {
    var x: Double
    var y: Double
    var z: Double
}

struct StitchAIPoint4D: Codable {
    var x: Double
    var y: Double
    var z: Double
    var w: Double
}






struct StitchAIColor: StitchAIStringConvertable {
    var value: Color
}


struct StitchAINetworkRequestType: StitchAIStringConvertable {
    enum RequestType: String, Codable {
        case get
        case post
    }
    
    var value: RequestType
    
    init(value: RequestType) {
        self.value = value
    }
}

struct StitchAICameraDirection: StitchAIStringConvertable {
    enum CameraDirection: String, Codable {
        case front
        case back
    }
    
    var value: CameraDirection
    
    init(value: CameraDirection) {
        self.value = value
    }
}

struct StitchAIScrollMode: StitchAIStringConvertable {
    enum ScrollMode: String, Codable {
        case free
        case paging
        case disabled
    }
    
    var value: ScrollMode
    
    init(value: ScrollMode) {
        self.value = value
    }
}

struct StitchAILayerTextAlignment: StitchAIStringConvertable {
    enum LayerTextAlignment: String, Codable {
        case left
        case center
        case right
        case justify
    }
    
    var value: LayerTextAlignment
    
    init(value: LayerTextAlignment) {
        self.value = value
    }
}

struct StitchAITextVerticalAlignment: StitchAIStringConvertable {
    enum TextVerticalAlignment: String, Codable {
        case top
        case center
        case bottom
    }
    
    var value: TextVerticalAlignment
    
    init(value: TextVerticalAlignment) {
        self.value = value
    }
}

struct StitchAIVisualMediaFitStyle: StitchAIStringConvertable {
    enum VisualMediaFitStyle: String, Codable {
        case fit
        case fill
        case stretch
    }
    
    var value: VisualMediaFitStyle
    
    init(value: VisualMediaFitStyle) {
        self.value = value
    }
}


struct StitchAIClassicAnimationCurve: StitchAIStringConvertable {
    enum ClassicAnimationCurve: String, Codable {
        case linear
        case quadraticIn
        case quadraticOut
        case sinusoidalIn
        case sinusoidalOut
        case sinusoidalInOut
        case exponentialIn
        case exponentialOut
        case exponentialInOut
    }
    
    var value: ClassicAnimationCurve
    
    init(value: ClassicAnimationCurve) {
        self.value = value
    }
}


struct StitchAILightType: StitchAIStringConvertable {
    enum LightType: String, Codable {
        case ambient
        case omni
        case directional
        case spot
        case probe
        case area
    }
    
    var value: LightType
    
    init(value: LightType) {
        self.value = value
    }
}

struct StitchAILayerStroke: StitchAIStringConvertable {
    enum LayerStroke: String, Codable {
        case none
        case inside
        case outside
    }
    
    var value: LayerStroke
    
    init(value: LayerStroke) {
        self.value = value
    }
}

struct StitchAITextTransform: StitchAIStringConvertable {
    enum TextTransform: String, Codable {
        case uppercase
        case lowercase
        case capitalize
    }
    
    var value: TextTransform
    
    init(value: TextTransform) {
        self.value = value
    }
}

struct StitchAIDateAndTimeFormat: StitchAIStringConvertable {
    enum DateAndTimeFormat: String, Codable {
        case none
        case short
        case medium
        case long
        case full
    }
    
    var value: DateAndTimeFormat
    
    init(value: DateAndTimeFormat) {
        self.value = value
    }
}

struct StitchAIScrollJumpStyle: StitchAIStringConvertable {
    enum ScrollJumpStyle: String, Codable {
        case animated
        case instant
    }
    
    var value: ScrollJumpStyle
    
    init(value: ScrollJumpStyle) {
        self.value = value
    }
}

struct StitchAIScrollDecelerationRate: StitchAIStringConvertable {
    enum ScrollDecelerationRate: String, Codable {
        case normal
        case fast
    }
    
    var value: ScrollDecelerationRate
    
    init(value: ScrollDecelerationRate) {
        self.value = value
    }
}

struct StitchAIDelayStyle: StitchAIStringConvertable {
    enum DelayStyle: String, Codable {
        case always = "Always"
        case increasing = "Increasing"
        case decreasing = "Decreasing"
    }
    
    var value: DelayStyle
    
    init(value: DelayStyle) {
        self.value = value
    }
}

extension StitchAIColor: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value.encodableString)
    }
}

struct StitchAIUUID: StitchAIStringConvertable {
    var value: UUID
}


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

struct StitchAISizeDimension: StitchAIStringConvertable {
    var value: LayerDimension
}

extension LayerDimension: StitchAIValueStringConvertable {
    var encodableString: String {
        self.description
    }
    
    public init?(_ description: String) {
        guard let result = Self.fromUserEdit(edit: description) else {
            return nil
        }
        
        self = result
    }
}

extension StitchAINetworkRequestType.RequestType: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAICameraDirection.CameraDirection: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAIScrollMode.ScrollMode: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAILayerTextAlignment.LayerTextAlignment: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAIVisualMediaFitStyle.VisualMediaFitStyle: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAIClassicAnimationCurve.ClassicAnimationCurve: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAITextVerticalAlignment.TextVerticalAlignment: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAILightType.LightType: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAILayerStroke.LayerStroke: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAITextTransform.TextTransform: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAIDateAndTimeFormat.DateAndTimeFormat: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}


extension StitchAIScrollJumpStyle.ScrollJumpStyle: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAIScrollDecelerationRate.ScrollDecelerationRate: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
    }
}

extension StitchAIDelayStyle.DelayStyle: StitchAIValueStringConvertable, CustomStringConvertible {
    var description: String {
        self.rawValue
    }
    
    var encodableString: String {
        self.rawValue
    }
    
    init?(_ description: String) {
        self.init(rawValue: description)
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
