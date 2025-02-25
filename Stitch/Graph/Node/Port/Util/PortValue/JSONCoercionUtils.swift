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
                // log("jsonCoercer: coerced \(self) to a json \(json) via rawValue")
                return .init(json)
            } else {
                return emptyStitchJSONObject
            }
            
        default:
                        
            // Encode the PortValue as a human-readable/friendly JSON (e.g. StitchAIColor instead of SwiftUI.Color)
            if let encoding: Data = try? getStitchEncoder().encode(self.anyCodable),
               let json = try? JSON.init(data: encoding) {
                // log("jsonCoercer: coerced \(self) to a json \(json) via encoding")
                return .init(json)
            }
                       
            // Best for enums: `SwiftyJSON.JSON(rawValue:)` cannot directly handle Swift enums, so we use the enum's human-friendly display instead.
            // Note: Can we go directly from a SwiftUI `Codable` to a SwiftyJSON?
            else if let rawValueStr = self.rawValueString,
                    let json: JSON = JSON(rawValue: rawValueStr) {
                // log("jsonCoercer: coerced \(self) to a json \(json) via rawValueStr i.e. \(rawValueStr)")
                return .init(json)
            }
            
            // TODO: when does this really happen? just e.g. PortValue.layerDimension ?
            else if let json: JSON = JSON(rawValue: self.display) {
                // log("jsonCoercer: coerced \(self) to a json \(json) via display i.e. \(self.display)")
                return .init(json)
            }
            
            // All our PortValues are (1) primitive SwiftUI types that have JSON-equivalents, (2) Encodable Swift Structs, or (3) Swift enums that have a human-friendly display representation.
            else {
                fatalErrorIfDebug() // We probably made some mistake
                // log("Failed to turn PortValue \(self) into a JSON", .logToServer)
                return emptyStitchJSONObject
            }
        }
    }
}

extension PortValue {
    var rawValueString: String? {
        
        switch self {
        case .plane(let x):
            return x.rawValue
        case .networkRequestType(let x):
            return x.rawValue
        case .cameraDirection(let x):
            return x.rawValue
        case .scrollMode(let x):
            return x.rawValue
        case .textAlignment(let x):
            return x.rawValue
        case .textVerticalAlignment(let x):
            return x.rawValue
        case .fitStyle(let x):
            return x.rawValue
        case .animationCurve(let x):
            return x.rawValue
        case .lightType(let x):
            return x.rawValue
        case .layerStroke(let x):
            return x.rawValue
        case .textTransform(let x):
            return x.rawValue
        case .dateAndTimeFormat(let x):
            return x.rawValue
        case .scrollJumpStyle(let x):
            return x.rawValue
        case .scrollDecelerationRate(let x):
            return x.rawValue
        case .delayStyle(let x):
            return x.rawValue
        case .shapeCoordinates(let x):
            return x.rawValue
        case .shapeCommandType(let x):
            return x.rawValue
        case .orientation(let x):
            return x.rawValue
        case .cameraOrientation(let x):
            return x.rawValue
        case .deviceOrientation(let x):
            return x.rawValue
        case .textDecoration(let x):
            return x.rawValue
        case .blendMode(let x):
            return x.rawValue
        case .mapType(let x):
            return x.rawValue
        case .progressIndicatorStyle(let x):
            return x.rawValue
        case .mobileHapticStyle(let x):
            return x.rawValue
        case .strokeLineCap(let x):
            return x.rawValue
        case .strokeLineJoin(let x):
            return x.rawValue
        case .contentMode(let x):
            return x.rawValue
        case .sizingScenario(let x):
            return x.rawValue
        case .deviceAppearance(let x):
            return x.rawValue
            
        case .materialThickness(let x):
            return x.rawValue
        case .vnImageCropOption(let x):
            return x.rawValue.description
            
        case .string,  .bool,  .int,  .number,  .layerDimension,  .transform,  .color,  .size,  .position,  .point3D,  .point4D,  .pulse,  .asyncMedia,  .json,  .none,  .anchoring,  .assignedLayer,  .shape,  .comparable,  .shapeCommand,  .textFont,  .spacing,  .padding,  .pinTo,  .anchorEntity:
            log("rawValueString: will return nil")
            return nil
        }
    }
}

extension JSON {
    func coerceJSONToPortValue(_ currentNodeTypeOnInput: NodeType) -> PortValue {
                
        // log("coerceToPortValue: json type: \(self.type)")
        
        let defaultReturnJSON = PortValue.json(.init(id: .init(), value: self))
        
        guard let encoded: Data = self.type == .dictionary ? (try? self.encodeToData()) : (try? self.stringValue.encodeToData()) else {
            // log("coerceToPortValue: could not encode data; will return JSON as PortValue.json")
            return defaultReturnJSON
        }
        
        let decoder = JSONDecoder()
        
        let attempToDecodeAs = { (nodeType: NodeType) -> PortValue? in
            
            // TODO: update the Decoder to handle "None" as the representation of `.assignedLayer(nil)`
            if nodeType == .interactionId,
               self.string == PortValue.assignedLayer(nil).display {
                return PortValue.assignedLayer(nil)
            }
            
            guard let decodedAnyValue = try? decoder.decode(nodeType.portValueTypeForStitchAI, from: encoded) else {
                // log("coerceToPortValue: could not decode json \(self) as \(nodeType)")
                return nil
            }
            
            guard let decodedPortValue: PortValue = try? nodeType.coerceToPortValueForStitchAI(from: decodedAnyValue) else {
                // log("coerceToPortValue: could not decode port value for json \(self) as \(nodeType)")
                return nil
            }
            
            // log("coerceToPortValue: got decodedPortValue: \(decodedPortValue) for existingValue \(nodeType)")
            return decodedPortValue
        }
        
        // First, attempt to decode JSON as the *input's current node type.*
        // Helpful for cases where, without additional context, the JSON could be equally decoded as more than one PortValue type.
        // e.g. a json-string `fill` could match either to VisualMediaFitStyle or LayerDimension
        if let valueFromJSON = attempToDecodeAs(currentNodeTypeOnInput) {
            return valueFromJSON
        }

        // Next, iterate through all remaining
        for nodeType in NodeType.allCases {
            // TODO: remove `PortValue.none` case
            // Note: String is handled last
            if nodeType == .none || nodeType == .string {
                continue
            }
            
            if let valueFromJSON = attempToDecodeAs(nodeType) {
                return valueFromJSON
            }
        } // for nodeType in ...
                
        
        // Finally:
        // rawValue enum cases are all json-strings, which we can be decoded as either String or the specific enum type (e.g. SizingScenario, VisualMediaFitStyle etc.).
        // We want to decode the JSON into the most specific type possible, so e.g. decode the json-string "stretch" as a VisualMediaFitStyle rather than just a String.
        // Thus, we attempt 'decode as String' LAST, after trying other types first.
        if let valueFromJSON = attempToDecodeAs(.string) {
            return valueFromJSON
        }
        
        // If we could not decode the JSON as some other more specific PortValue type,
        // simply continue to treat it as a JSON PortValue type.
        else {
            // log("coerceToPortValue: could not get PortValue from json \(self)")
            return defaultReturnJSON
        }
    }
}
