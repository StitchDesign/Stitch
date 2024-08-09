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
    case hW, xY, xYZ, xYZW, padding, spacing, dropdown, bool, asyncMedia, number, string, readOnly, layerDimension, pulse, color, json, assignedLayer, anchoring, pinTo
}

extension FieldGroupType {
    var labels: [String] {
        switch self {
        case .hW:
            return [SIZE_WIDTH_LABEL, SIZE_HEIGHT_LABEL]
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
        case .dropdown, .bool, .asyncMedia, .number, .string, .readOnly, .layerDimension, .pulse, .color, .json, .assignedLayer, .anchoring, .spacing, .pinTo:
            return [""]
        }
    }

    var defaultFieldValues: FieldValues {
        switch self {
        case .hW, .xY:
            return [.number(.zero), .number(.zero)]

        case .xYZ:
            return [.number(.zero), .number(.zero), .number(.zero)]

        case .xYZW:
            return [.number(.zero), .number(.zero), .number(.zero), .number(.zero)]

        case .padding:
            return [.number(.zero), .number(.zero), .number(.zero), .number(.zero)]
            
        case .spacing:
            return [.spacing(.defaultStitchSpacing)]
            
        case .number:
            return [.number(.zero)]

        case .dropdown:
            return [.dropdown("", [])]

        case .bool:
            return [.bool(false)]

        case .asyncMedia:
            return [.media(.none)]

        case .string:
            return [.string(.init(""))]

        case .layerDimension:
            return [.layerDimension(.number(.zero))]

        case .pulse:
            return [.pulse(.infinity)]

        case .color:
            return [.color(falseColor)]

        case .json:
            return [.json(StitchJSON.emptyJSONObject)]

        case .assignedLayer:
            return [.layerDropdown(nil)]

        case .pinTo:
            return [.pinTo(.defaultPinToId)]
            
        case .anchoring:
            return [.anchorPopover(.defaultAnchoring)]

        case .readOnly:
            return [.readOnly("")]
        }
    }
}
