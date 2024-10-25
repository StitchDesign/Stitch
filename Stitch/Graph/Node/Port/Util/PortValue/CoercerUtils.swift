//
//  CoercerUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/22/24.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreML

extension PortValue {
    func coerceToTruthyOrFalsey(graphTime: TimeInterval = 0.0) -> Bool {
        Stitch.coerceToTruthyOrFalsey(self, graphTime: graphTime)
    }
}

// TODO: update to handle more PortValue cases
func coerceToTruthyOrFalsey(_ value: PortValue,
                            // Only for .pulse coercion cases
                            graphTime: TimeInterval = 0.0) -> Bool {

    //    log("coerceToTruthyOrFalsey: value: \(value)")
    //    log("coerceToTruthyOrFalsey: graphTime: \(graphTime)")

    switch value {
    case .bool(let x):
        return x
    case .int(let x):
        return x > 0
    case .number(let x):
        return x > 0.0
    case .layerDimension(let x):
        return x.asBool
    case .size(let x):
        return x != .zero
    case .position(let x):
        return x != .zero
    case .string(let x):
        return x.string != ""
    case .color(let x):
        return x != falseColor
    case .pulse(let x):
        // A pulse is true
        return x == graphTime
    case .json(let x):
        return x.value != ""
    case .point3D(let x):
        return x != Point3D.zero
    case .assignedLayer(let x):
        return x != nil
    case .scrollMode(let x):
        return x != .disabled
    case .none:
        return false
    default:
        return true
    }
}

extension PortValues {
    /*
     The sole responsibility of this function is to coerce a list of PortValues; does not differentiate between input or output, does not create side-effects for camera orientation change etc.
     */
    // TODO: replace `thisType: PortValue` with `thisType: UserVisibleType`
    func coerce(to thisType: PortValue,
                // for pulses
                currentGraphTime: TimeInterval) -> Self {

        let values = self

        switch thisType {
        case .string:
            return stringCoercer(values)
        case .bool:
            return boolCoercer(values)
        case .int:
            return intCoercer(values)
        case .number:
            return numberCoercer(values)
        case .layerDimension:
            return layerDimensionCoercer(values)
        case .pulse:
            return pulseCoercer(values, graphTime: currentGraphTime)
        case .color:
            return colorCoercer(values)
        case .size:
            return sizeCoercer(values)
        case .position:
            return positionCoercer(values)
        case .point3D:
            return point3DCoercer(values)
        case .point4D:
            return point4DCoercer(values)
        case .transform:
            return transformCoercer(values)
        case .asyncMedia:
            return asyncMediaCoercer(values)
        case .json:
            return jsonCoercer(values)
        case .networkRequestType:
            return networkRequestTypeCoercer(values)
        case .none:
            return values  // no way to coerce
        case .anchoring:
            return anchoringCoercer(values)
        case .assignedLayer:
            return interactionIdCoercer(values)
        case .scrollMode:
            return scrollModeCoercer(values)
        case .textAlignment:
            return textAlignmentCoercer(values)
        case .textVerticalAlignment:
            return textVerticalAlignmentCoercer(values)
        case .fitStyle:
            return fitStyleCoercer(values)
        case .animationCurve:
            return animationCurveCoercer(values)
        case .lightType:
            return lightTypeCoercer(values)
        case .layerStroke:
            return layerStrokeCoercer(values)
        case .textTransform:
            return textTransformCoercer(values)
        case .dateAndTimeFormat:
            return dateAndTimeFormatCoercer(values)
        case .shape:
            return shapeCoercer(values)
        case .scrollJumpStyle:
            return scrollJumpStyleCoercer(values)
        case .scrollDecelerationRate:
            return scrollDecelerationRateCoercer(values)
        case .plane:
            return planeCoercer(values)
        case .comparable:
            return comparableCoercer(values)
        case .delayStyle:
            return delayStyleCoercer(values)
        case .shapeCoordinates:
            return shapeCoordinatesCoercer(values)
        case .shapeCommand:
            return shapeCommandCoercer(values)
        case .shapeCommandType:
            // TODO: this logic will change when we update the ShapeCommand UX ?
            return shapeCommandTypeCoercer(thisType, values)
        case .orientation:
            return orientationCoercer(values)
        case .cameraOrientation:
            return cameraOrientationCoercer(values)
        case .cameraDirection:
            return cameraDirectionCoercer(values)
        case .deviceOrientation:
            return deviceOrientationCoercer(values)
        case .vnImageCropOption:
            return vnImageCropCoercer(values)
        case .textDecoration:
            return textDecorationCoercer(values)
        case .textFont:
            return textFontCoercer(values)
        case .blendMode:
            return blendModeCoercer(values)
        case .mapType:
            return mapTypeCoercer(values)
        case .progressIndicatorStyle:
            return progressIndicatorStyleCoercer(values)
        case .mobileHapticStyle:
            return mobileHapticStyleCoercer(values)
        case .strokeLineCap:
            return strokeLineCapCoercer(values)
        case .strokeLineJoin:
            return strokeLineJoinCoercer(values)
        case .contentMode:
            return contentModeCoercer(values)
        case .spacing:
            return spacingCoercer(values)
        case .padding:
            return paddingCoercer(values)
        case .sizingScenario:
            return sizingScenarioCoercer(values)
        case .pinTo:
            return pinToCoercer(values)
        case .deviceAppearance:
            return deviceAppearanceCoercer(values)
        case .materialThickness:
            return materialThicknessCoercer(values)
        }
    }
}

// TODO: this should be defined on inputs but not outputs
extension NodeRowObserver {
    /*
     Coerce the passed in PortValues to the type represented by `thisType: PortValue`.

     There are two use cases:

     1. Setting new values in an existing input:
     `(values: [P], input: [T]) -> input: [T]`
     e.g. ``

     2. Changing an existing input’s type: e.g. `NodeRowObserver.changeInputType`
     `(newType: P, input: [T]) -> input: [P]`

     */
    @MainActor
    func coerceUpdate(these values: PortValues,
                      to thisType: PortValue,

                      // Additional data used for input coercion:
                      currentGraphTime: TimeInterval) {

        let newValues = values.coerce(to: thisType,
                                      currentGraphTime: currentGraphTime)

        // Update new values to input observer
        self.updateValues(newValues)
    }
}
