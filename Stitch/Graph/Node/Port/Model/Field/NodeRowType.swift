//
//  Fields.swift
//  Stitch
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
         size3D,
         position,
         point3D,
         point4D,
         padding,
         shapeCommand(ShapeCommandFieldType),
         singleDropdown(SingleDropdownKind),
         textFontDropdown, // TODO: special case because nested?
         layerGroupOrientationDropdown,
         layerGroupAlignment,
         textAlignmentPicker,
         textVerticalAlignmentPicker,
         textDecoration,
         spacing, // uses TextField + Dropdown
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
         anchoring,
         pinTo,
         anchorEntity,
         transform3D
}

extension NodeRowType {
    
    // TODO: smarter / easier to way to do this?
    func inputUsesTextField(isLayerInputInspector: Bool) -> Bool {
        switch self {
        case .size, .size3D, .position, .point3D, .point4D, .padding, .layerDimension, .number, .string, .spacing, .transform3D:
            return true
        case .readOnly, .shapeCommand, .singleDropdown, .textFontDropdown, .bool, .asyncMedia, .pulse, .color, .json, .assignedLayer, .anchoring, .pinTo, .layerGroupOrientationDropdown, .anchorEntity, .layerGroupAlignment, .textAlignmentPicker, .textVerticalAlignmentPicker, .textDecoration:
            return false
        }
    }
    
    var defaultValue: PortValue {
        switch self {
        case .size:
            return defaultSizeFalse
        case .size3D:
            return .point3D(.init(x: 0, y: 0, z: 0))
        case .position:
            return defaultPositionFalse
        case .point3D:
            return .point3D(.init(x: 0, y: 0, z: 0))
        case .point4D:
            return .point4D(.init(x: 0, y: 0, z: 0, w: 0))
        case .padding:
            return .padding(.zero)
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
        case .spacing:
            return .spacing(.defaultStitchSpacing)
        case .pinTo:
            return .pinTo(.defaultPinToId)
        case .layerGroupOrientationDropdown:
            return .orientation(.defaultOrientation)
        case .anchorEntity:
            return .anchorEntity(nil)
        case .transform3D:
            return .transform(.zero)
        case .layerGroupAlignment:
            // LayerGroupAlignment node row type and field value case use PortValue.anchoring
            return .anchoring(.topLeft)
        case .textAlignmentPicker:
            return .textAlignment(DEFAULT_TEXT_ALIGNMENT)
        case .textVerticalAlignmentPicker:
            return .textVerticalAlignment(DEFAULT_TEXT_VERTICAL_ALIGNMENT)
        case .textDecoration:
            return .textDecoration(.defaultLayerTextDecoration)
        }
    }
}

enum ShapeCommandFieldType: Encodable {
    case closePath, lineTo, curveTo, output
}
