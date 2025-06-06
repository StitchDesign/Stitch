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
    func coerceToTruthyOrFalsey(_ graphTime: TimeInterval) -> Bool {
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
        // A pulse is true if we're 
        return x == graphTime && graphTime != .zero
    case .json(let x):
        // TODO: https://github.com/StitchDesign/Stitch--Old/issues/6939
        return x.value.bool ?? x.value.isEmpty
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
            return boolCoercer(values, graphTime: currentGraphTime)
        case .number:
            return numberCoercer(values, graphTime: currentGraphTime)
        case .layerDimension:
            return layerDimensionCoercer(values, graphTime: currentGraphTime)
        case .pulse:
            return pulseCoercer(values, graphTime: currentGraphTime)
        case .color:
            return colorCoercer(values, graphTime: currentGraphTime)
        case .size:
            return sizeCoercer(values, graphTime: currentGraphTime)
        case .position:
            return positionCoercer(values, graphTime: currentGraphTime)
        case .point3D:
            return point3DCoercer(values, graphTime: currentGraphTime)
        case .point4D:
            return point4DCoercer(values, graphTime: currentGraphTime)
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
            return spacingCoercer(values, graphTime: currentGraphTime)
        case .padding:
            return paddingCoercer(values, graphTime: currentGraphTime)
        case .sizingScenario:
            return sizingScenarioCoercer(values)
        case .pinTo:
            return pinToCoercer(values)
        case .deviceAppearance:
            return deviceAppearanceCoercer(values)
        case .materialThickness:
            return materialThicknessCoercer(values)
        case .anchorEntity:
            return self.anchorEntityCoercer(values: self)
        case .keyboardType(_):
            return keyboardTypeCoercer(values)
        }
    }
}

extension InputNodeRowObserver {
    
    // Used by StitchEngine when checking whether
    // a downstream input value has changed.
    @MainActor
    func coerce(theseValues: [PortValue],
                toThisType: PortValue,
                currentGraphTime: TimeInterval) -> [PortValue] {
        
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return theseValues
        }
        
        let canCopyInputValues = node.kind.patchOrLayer?.canCopyInputValues(
            portId: self.id.portId,
            userVisibleType: node.userVisibleType) ?? false
        
        if canCopyInputValues {
            return theseValues
        } else {
            return theseValues.coerce(to: toThisType,
                                      currentGraphTime: currentGraphTime)
        }
    }
    
}
