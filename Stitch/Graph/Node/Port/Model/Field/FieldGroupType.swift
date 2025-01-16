//
//  FieldGroupType.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import StitchSchemaKit

/// Represents each individual field grouping encompassing an entire port value) (i.e. x + y coordinate)
enum FieldGroupType {
    case wH, wHL, xY, xYZ, xYZW, padding, spacing, dropdown, bool, asyncMedia, number, string, readOnly, layerDimension, pulse, color, json, assignedLayer, anchoring, pinTo, layerGroupOrientation, anchorEntity
}

extension FieldGroupType {
    var labels: [String] {
        switch self {
        case .wH:
            return [SIZE_WIDTH_LABEL, SIZE_HEIGHT_LABEL]
        case .wHL:
            return [SIZE_WIDTH_LABEL, SIZE_HEIGHT_LABEL, SIZE_LENGTH_LABEL]
        case .xY:
            return [POSITION_FIELD_X_LABEL, POSITION_FIELD_Y_LABEL]
        case .xYZ:
            return [POINT3D_X_LABEL, POINT3D_Y_LABEL, POINT3D_Z_LABEL]
        case .xYZW:
            return [POINT3D_X_LABEL, POINT3D_Y_LABEL, POINT3D_Z_LABEL, POINT4D_W_LABEL]
        case .padding:
            return [
                PADDING_TOP_FIELD_LABEL,
                PADDING_RIGHT_FIELD_LABEL,
                PADDING_BOTTOM_FIELD_LABEL,
                PADDING_LEFT_FIELD_LABEL
            ]
        case .number, .dropdown, .bool, .asyncMedia, .string, .readOnly, .layerDimension, .pulse, .color, .json, .assignedLayer, .anchoring, .spacing, .pinTo, .layerGroupOrientation, .anchorEntity:
            return [""]
        }
    }
}
