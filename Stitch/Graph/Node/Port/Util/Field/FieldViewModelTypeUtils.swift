//
//  PortValueFields.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/3/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension PortValue {
    static func createSingleFieldDropdown(_ selection: String,
                                          _ choices: PortValues,
                                          _ coordinate: NodeIOCoordinate) -> FieldViewModelType {
        .single(
            FieldViewModel(fieldValue: .dropdown(selection, choices),
                           coordinate: coordinate,
                           fieldIndex: 0,
                           fieldLabel: "")
        )
    }

    func getNodeRowType(nodeIO: NodeIO) -> NodeRowType {
        switch self {
        case .size:
            return .size
        case .position:
            return .position
        case .point3D:
            return .point3D
        case .point4D:
            return .point4D
        case .shapeCommand(let shapeCommand):
            switch nodeIO {
            case .input:
                switch shapeCommand {
                case .closePath:
                    return .shapeCommand(.closePath)
                case .moveTo, .lineTo:
                    return .shapeCommand(.lineTo)
                case .curveTo:
                    return .shapeCommand(.curveTo)

                }
            case .output:
                return .readOnly
            }

        // MARK: - single field dropdowns
        case .textAlignment:
            return .singleDropdown(.textAlignment)
        case .textVerticalAlignment:
            return .singleDropdown(.textVerticalAlignment)
        case .textDecoration:
            return .singleDropdown(.textDecoration)
        case .textFont:
            return .textFontDropdown
        case .blendMode:
            return .singleDropdown(.blendMode)
        case .fitStyle:
            return .singleDropdown(.fitStyle)
        case .animationCurve:
            return .singleDropdown(.animationCurve)
        case .cameraDirection:
            return .singleDropdown(.cameraDirection)
        case .plane:
            return .singleDropdown(.plane)
        case .scrollMode:
            return .singleDropdown(.scrollMode)
        case .lightType:
            return .singleDropdown(.lightType)
        case .networkRequestType:
            return .singleDropdown(.networkRequestType)
        case .layerStroke:
            return .singleDropdown(.layerStroke)
        case .textTransform:
            return .singleDropdown(.textTransform)
        case .dateAndTimeFormat:
            return .singleDropdown(.dateAndTimeFormat)
        case .scrollJumpStyle:
            return .singleDropdown(.scrollJumpStyle)
        case .scrollDecelerationRate:
            return .singleDropdown(.scrollDecelerationRate)
        case .delayStyle:
            return .singleDropdown(.delayStyle)
        case .shapeCoordinates:
            return .singleDropdown(.shapeCoordinates)
        case .shapeCommandType:
            return .singleDropdown(.shapeCommandType)
        case .orientation:
            return .singleDropdown(.orientation)
        case .cameraOrientation:
            return .singleDropdown(.cameraOrientation)
        case .deviceOrientation:
            return .singleDropdown(.deviceOrientation)
        case .vnImageCropOption:
            return .singleDropdown(.vnImageCropAndScale)

        // MARK: - other
        case .bool:
            return .bool

        case .asyncMedia:
            return .asyncMedia

        case .number, .int:
            return .number

        case .string:
            return .string

        case .comparable(let comparable):
            switch comparable {
            case .none:
                return .readOnly
            case .number:
                return .number
            case .string:
                return .string
            case .bool:
                return .bool
            }
        case .layerDimension:
            return .layerDimension
        case .pulse:
            return .pulse
        case .color:
            return .color
        case .json:
            return .json
        case .assignedLayer:
            return .assignedLayer
        case .anchoring:
            return .anchoring
        case .matrixTransform, .none,
            // TODO: should be able to tap a Shape input/output to see the constituent JSON ?
                .shape:
            return .readOnly
        case .mapType:
            return .singleDropdown(.mapType)
        case .progressIndicatorStyle:
            return .singleDropdown(.progressIndicatorStyle)
        case .mobileHapticStyle:
            return .singleDropdown(.mobileHapticStyle)
        case .strokeLineCap(_):
            return .singleDropdown(.strokeLineCap)
        case .strokeLineJoin(_):
            return .singleDropdown(.strokeLineJoin)
        case .contentMode(_):
            return .singleDropdown(.contentMode)
            
            // TODO: need new kind of field that supports text + dropdown; will be reused with LayerDimension field as well
        case .spacing:
            return .singleDropdown(.spacing)
        }
    }

    /*
     Do we use a drop-down menu to select this PortValue?
     If so, then we'll want to use the length of the longest menu option
     to determine the width of this input.

     See also `Patch.usesCustomValueSpaceWidth`
     TODO: unify these "patch uses media import picker" and "port-value uses dropdown picker" concepts ?
     */
    var alwaysUsesDropDownMenu: Bool {
        switch self {
        case .bool, .anchoring,
             .textAlignment, .textVerticalAlignment,
             .animationCurve, .cameraDirection,
             .fitStyle, .scrollMode,
             .assignedLayer, .plane, .mapType:
            return true
        default:
            return false
        }
    }

    // Can this parent value's fields use `auto`, '50%` etc.?
    var canUseAuto: Bool {
        if self.getLayerDimension.isDefined || self.getSize.isDefined {
            return true
        }
        return false
    }
}
