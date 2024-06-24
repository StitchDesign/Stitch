//
//  Fields.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/26/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import Vision

// Represents an entire input/output in the UI: how many fields, whether we use a dropdown etc.
enum NodeRowType: Equatable {
    case size,
         position,
         point3D,
         point4D,
         shapeCommand(ShapeCommandFieldType),
         singleDropdown(SingleDropdownKind),
         textFontDropdown, // TODO: special case because nested?
         bool, 
         asyncMedia,
         number,
         string,
         readOnly,
         layerDimension,
         pulse,
         color,
         json,
         assignedLayer,
         anchoring
}

extension NodeRowType {
    
    // TODO: smarter / easier to way to do this?
    var inputUsesTextField: Bool {
        switch self {
          case .size, .position, .point3D, .point4D, .layerDimension, .number, .string:
            return true
        case .readOnly, .shapeCommand, .singleDropdown, .textFontDropdown, .bool, .asyncMedia, .pulse, .color, .json, .assignedLayer, .anchoring:
            return false
        }
    }
    
    var defaultValue: PortValue {
        switch self {
        case .size:
            return defaultSizeFalse
        case .position:
            return defaultPositionFalse
        case .point3D:
            return .point3D(.init(x: 0, y: 0, z: 0))
        case .point4D:
            return .point4D(.init(x: 0, y: 0, z: 0, w: 0))
        case .shapeCommand:
            return .shapeCommand(ShapeCommand.defaultFalseShapeCommand)
        case .singleDropdown(let singleDropdownKind):
            return singleDropdownKind.choices.first ?? boolDefaultFalse
        case .bool:
            return boolDefaultFalse
        case .asyncMedia:
            return .asyncMedia(nil)
        case .number:
            return defaultNumber
        case .string:
            return .string(.init(""))
        case .readOnly:
            return .string(.init(""))
        case .layerDimension:
            return .layerDimension(.number(.zero))
        case .pulse:
            return .pulse(.zero)
        case .color:
            return .color(.falseColor)
        case .json:
            return defaultFalseJSON
        case .assignedLayer:
            return .assignedLayer(nil)
        case .anchoring:
            return .anchoring(.topLeft)
        case .textFontDropdown:
            return .textFont(.defaultStitchFont)
        }
    }
}

enum ShapeCommandFieldType: Encodable {
    case closePath, lineTo, curveTo, output
}
