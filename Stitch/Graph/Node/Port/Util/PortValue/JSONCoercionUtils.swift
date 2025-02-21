//
//  JSONCoercionUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/20/25.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

extension PortValue {
    var coerceToHumanFriendlyJSON: StitchJSON {
        
        switch self {
            
        case .json(let x):
            return x
            
        case .shape(let shape):
            if let shape = shape {
                // Note: for now, keep JSON <-> Shape specific conversion data, since it handles e.g. "X" vs "x" in a JSON better?
                return shape.asJSON.toStitchJSON
            } else {
                return emptyStitchJSONObject
            }
            
        case .number, .string, .bool:
            // Swift types that have direct JSON equivalents: (json-number, json-bool, json-string) need to use SwiftyJSON's `JSON(rawValue:)`.
            if let json: JSON = JSON(rawValue: self.anyCodable as Any) {
                log("jsonCoercer: coerced \(self) to a json \(json) via rawValue")
                return .init(json)
            } else {
                return emptyStitchJSONObject
            }
            
        default:
            // Encode the PortValue as a human-readable/friendly JSON (e.g. StitchAIColor instead of SwiftUI.Color)
            if let encoding: Data = try? getStitchEncoder().encode(self.anyCodable),
               let json = try? JSON.init(data: encoding) {
                log("jsonCoercer: coerced \(self) to a json \(json) via encoding")
                return .init(json)
            }
            
            // Best for enums: `SwiftyJSON.JSON(rawValue:)` cannot directly handle Swift enums, so we use the enum's human-friendly display instead.
            // Note: Can we go directly from a SwiftUI `Codable` to a SwiftyJSON?
            else if let json: JSON = JSON(rawValue: self.display) {
                log("jsonCoercer: coerced \(self) to a json \(json) via display i.e. \(self.display)")
                return .init(json)
            }
            
            // All our PortValues are (1) primitive SwiftUI types that have JSON-equivalents, (2) Encodable Swift Structs, or (3) Swift enums that have a human-friendly display representation.
            else {
                fatalErrorIfDebug() // We probably made some mistake
                return emptyStitchJSONObject
            }
        }
    }
}

extension JSON {
    // We have a PortValue.json flowing into an input with a PortValue.nonJSONCase value;
    // we want to convert the JSON into the existing value's PortValue case.
    
    // TODO: an input of a certain type is receiving a PortValue.json(StitchJSON) value; the JSON could represent any other PortValue, completely different from the
    // i.e. `JSON` is a kind of `Any` type.
    func coerceToPortValue(ofType nodeType: NodeType) -> PortValue {
        
        switch nodeType {
        case .json:
            return .json(.init(self)) // Not really how this is supposed to be used?
            //        case .shape:
            //            return .shape(self.coerceToCustomShape)
            //        case .number:
            //            return .number(self.double ?? .zero)
            //        case .bool:
            //            return .bool(self.bool ?? false)
            //        case .string:
            //            return .string(.init(self.string ?? .empty))
            //        case .int:
            //            return .int(self.int ?? .zero)
            //
            
        default:
            if let valueFromJSON: PortValue = try? nodeType.coerceToPortValueForStitchAI(from: self) {
                log("coerceToPortValue: got valueFromJSON: \(valueFromJSON) for existingValue \(nodeType)")
                return valueFromJSON
            } else {
                log("coerceToPortValue: could not get PortValue from json \(self) for existingValue \(nodeType)")
                return nodeType.defaultPortValue
            }
        }
    }
}
