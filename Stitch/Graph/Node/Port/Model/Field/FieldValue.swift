//
//  FieldValue.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/1/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SwiftyJSON

// Certain kinds of PortValues can be decomposed into two or more FieldValues
// eg `PortValue .position` -> `(FieldValue .number(x), FieldValue .number(y))`

typealias FieldValues = [FieldValue]

// TODO: rather than "number or string", the real cases are "number or parentPercent (eg 50%) or auto"
enum FieldValue: Equatable, Sendable {
    case string(StitchStringValue)
    case number(Double)
    case layerDimension(LayerDimensionField)
    case bool(Bool)
    case color(Color)
    case dropdown(String, PortValues)
    case layerDropdown(LayerNodeId?)
    case layerGroupOrientationDropdown(StitchOrientation)
    case pinTo(PinToId)
    case anchorPopover(Anchoring)
    case media(FieldValueMedia)
    case pulse(TimeInterval)
    case json(StitchJSON)
    case readOnly(String)
    case textFontDropdown(StitchFont)
    case spacing(StitchSpacing)
}

extension FieldValue {

    // For displaying preview of port-value
    // when user has clicked on an input or output
    var portValuePreview: String {
        switch self {
        case .string, .number, .layerDimension, .json:
            return self.stringValue
        case .dropdown(let x, _):
            return x
        case .media: // TODO: retrieve actual filename?
            return "media"
        case .readOnly(let x):
            return x
        case .bool(let x):
            return x.description
        case .pulse(let x):
            return x.description
        case .anchorPopover(let x):
            return x.display
        case .pinTo(let x):
            return x.display
        // case .layerDropdown(let x): // TODO: retrieve layer name?
            // TODO: provide real values here
        case .layerGroupOrientationDropdown(let x):
            return x.display
        case .color, .layerDropdown, .textFontDropdown, .spacing:
            return ""
        }
    }

    // Where and how is this used? Perhaps should return `String?`
    var stringValue: String {
        switch self {
        case .string(let string):
            return string.string
        case .readOnly(let string):
            return string
        case .number(let double):
            // return GlobalFormatter.string(for: double) ?? double.description
            return double.description
        case .layerDimension(let numberValue):
            return numberValue.stringValue
        case .json(let json):
            return json.display
        case .bool(let bool):
            return bool.description
        case .spacing(let spacing):
            return spacing.display
        case .pinTo(let x):
            return x.display
        case .layerGroupOrientationDropdown(let x):
            return x.display
        case .color, .dropdown, .layerDropdown, .anchorPopover, .media, .pulse, .textFontDropdown:
            return ""
        }
    }

    var numberValue: Double {
        switch self {
        case .number(let double):
            return double
        case .layerDimension(let numberValue):
            return numberValue.numberValue ?? .zero
        default:
            return .zero
        }
    }

    var layerDimensionField: LayerDimensionField? {
                
        switch self {
        
        case .layerDimension(let x):
            return x
            
        case .number(let fieldValueNumber):
            return .number(fieldValueNumber)
            
        case .string(let stitchString):
            let stringValue = stitchString.string
            
            // Parse for percentage first
            if stringValue.isPercentageField {
                let split = stringValue.split { $0 == "%" }

                // Valid percentage has one element when performing split
                guard split.count == 1,
                      let stringValue = split.first,
                      let number = Double(stringValue) else {
                    return .number(.zero)
                }

                return .percent(number)
            }
            // "Auto" condition etc.
            else if stringValue.lowercased() == .AUTO_SIZE_STRING {
                return .auto
            } else if stringValue.lowercased() == .FILL_SIZE_STRING {
                return .fill
            } else if stringValue.lowercased() == .HUG_SIZE_STRING {
                return .hug
            } else {
                // Number condition
                return .number(Double(stringValue) ?? .zero)
                
            }

        case .bool, .color, .dropdown, .layerDropdown, .pinTo, .anchorPopover, .media, .pulse, .json, .readOnly, .textFontDropdown, .spacing, .layerGroupOrientationDropdown:
            return nil
        }
    }

    var isCurrentValueAuto: Bool {
        self.stringValue == .AUTO_SIZE_STRING
    }
}
