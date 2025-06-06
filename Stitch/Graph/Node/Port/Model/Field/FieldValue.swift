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
    case layerGroupAlignment(Anchoring)
    case textAlignmentPicker(LayerTextAlignment)
    case textVerticalAlignmentPicker(LayerTextVerticalAlignment)
    case textDecoration(LayerTextDecoration)
    case pinTo(PinToId)
    case anchorPopover(Anchoring)
    case media(FieldValueMedia)
    case pulse(TimeInterval)
    case json(StitchJSON)
    case readOnly(String)
    case textFontDropdown(StitchFont)
    case spacing(StitchSpacing)
    case anchorEntity(UUID?)
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
        case .media(let x): // TODO: retrieve actual filename?
            return x.name
        case .readOnly(let x):
            return x
        case .bool(let x):
            return x.description
        case .pulse(let x): // TODO: show port that pulses, rather than the graph time?
            return x.description
        case .pinTo(let x):
            return x.display
        // case .layerDropdown(let x): // TODO: retrieve layer name?
            // TODO: provide real values here
        case .layerGroupOrientationDropdown(let x):
            return x.display
        case .layerDropdown(let x):
            return x?.asNodeId.description ?? "None"
        case .textFontDropdown(let x):
            return x.display
        case .spacing(let x):
            return x.display
            // Handled by own views
        case .color, .anchorPopover:
            return ""
        case .anchorEntity(let nodeId):
            return nodeId?.description ?? "None"
        case .layerGroupAlignment(let x):
            return x.display
        case .textAlignmentPicker(let x):
            return x.display
        case .textVerticalAlignmentPicker(let x):
            return x.display
        case .textDecoration(let x):
            return x.display
        }
    }

    var stringValue: String {
        switch self {
        case .string(let string):
            return string.string
        case .readOnly(let string):
            return string
        case .number(let double):
            return GlobalFormatter.string(for: double) ?? double.description
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
        case .color, .dropdown, .layerDropdown, .anchorPopover, .media, .pulse, .textFontDropdown, .anchorEntity, .layerGroupAlignment, .textAlignmentPicker, .textVerticalAlignmentPicker, .textDecoration:
            return ""
        }
    }

    var isNumberForArrowKeyIncrementAndDecrement: Bool {
        switch self {
        case .number:
            return true
        case .layerDimension(let x):
            switch x {
            case .number, .percent:
                return true
            default:
                return false
            }
        default:
            return false
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
            else if stringValue.lowercased() == LayerDimension.AUTO_SIZE_STRING {
                return .auto
            } else if stringValue.lowercased() == LayerDimension.FILL_SIZE_STRING {
                return .fill
            } else if stringValue.lowercased() == LayerDimension.HUG_SIZE_STRING {
                return .hug
            } else {
                // Number condition
                return .number(Double(stringValue) ?? .zero)
                
            }

        case .bool, .color, .dropdown, .layerDropdown, .pinTo, .anchorPopover, .media, .pulse, .json, .readOnly, .textFontDropdown, .spacing, .layerGroupOrientationDropdown, .anchorEntity, .layerGroupAlignment, .textAlignmentPicker, .textVerticalAlignmentPicker, .textDecoration:
            return nil
        }
    }

    var isCurrentValueAuto: Bool {
        self.stringValue == LayerDimension.AUTO_SIZE_STRING
    }
}
