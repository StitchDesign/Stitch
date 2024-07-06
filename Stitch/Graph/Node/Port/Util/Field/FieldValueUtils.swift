//
//  FieldValueUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import Vision
import StitchSchemaKit

extension PortValue {
    /// Coercion logic from port value to fields. Contains a 2D list of field values given a 1-many mapping between a field group type and its field values.
    func createFieldValues(nodeIO: NodeIO,
                           importedMediaObject: StitchMediaObject?) -> [FieldValues] {
        switch self.getNodeRowType(nodeIO: nodeIO) {
        case .size:
            let size = self.getSize ?? .zero
            return [size.fieldValues]
        case .position:
            let position = self.getPosition ?? .zero
            return [position.fieldValues]

        case .point3D:
            let point3D = self.getPoint3D ?? .zero
            return [point3D.fieldValues]

        case .point4D:
            let point4D = self.getPoint4D ?? .zero
            return [point4D.fieldValues]

        case .shapeCommand(let shapeCommandType):
            let shapeCommandValue = self.shapeCommand ?? .defaultFalseShapeCommand

            let commandTypeDropdownField = FieldValue.dropdown(shapeCommandValue.dropdownLabel, ShapeCommandType.choices)

            switch shapeCommandType {
            case .closePath, .lineTo, .curveTo:
                switch shapeCommandValue {
                case .closePath:
                    return [[commandTypeDropdownField]]

                case .lineTo(let point), .moveTo(let point):
                    let size = point.asCGSize
                    return [[commandTypeDropdownField], size.fieldValues]

                case .curveTo(let curveFrom, let point, let curveTo):
                    return [[commandTypeDropdownField],
                            point.asCGSize.fieldValues,
                            curveFrom.asCGSize.fieldValues,
                            curveTo.asCGSize.fieldValues]
                }
            case .output:
                return [[.readOnly(shapeCommandValue.display)]]
            }

        case .singleDropdown(let singleDropdownKind):
            switch singleDropdownKind {
            case .textAlignment:
                let textAlignment = self.getLayerTextAlignment?.display ?? .empty
                let choices = LayerTextAlignment.choices
                return [[.dropdown(textAlignment, choices)]]
                
            case .textVerticalAlignment:
                let textVerticalAlignment = self.getLayerTextVerticalAlignment?.display ?? .empty
                let choices = LayerTextVerticalAlignment.choices
                return [[.dropdown(textVerticalAlignment, choices)]]
                
            case .textDecoration:
                let textDecoration = self.getTextDecoration?.display ?? .empty
                let choices = LayerTextDecoration.choices
                return [[.dropdown(textDecoration, choices)]]
                
            case .blendMode:
                let blendMode = self.getBlendMode?.display ?? .empty
                let choices = StitchBlendMode.choices
                return [[.dropdown(blendMode, choices)]]
                
            case .fitStyle:
                let fitStyle = self.getFitStyle?.rawValue ?? .empty
                let choices = VisualMediaFitStyle.choices
                return [[.dropdown(fitStyle, choices)]]
                
            case .animationCurve:
                let animationCurve = self.getAnimationCurve?.displayName ?? .empty
                let choices = ClassicAnimationCurve.choices
                return [[.dropdown(animationCurve, choices)]]
                
            case .cameraDirection:
                let cameraDirection = self.getCameraDirection?.display ?? .empty
                let choices = CameraDirection.choices
                return [[.dropdown(cameraDirection, choices)]]
                
            case .cameraOrientation:
                let cameraOrientation = self.getCameraOrientation?.rawValue ?? .empty
                let choices = StitchCameraOrientation.choices
                return [[.dropdown(cameraOrientation, choices)]]
                
            case .deviceOrientation:
                let deviceOrientation = self.getDeviceOrientation?.rawValue ?? .empty
                let choices = StitchDeviceOrientation.choices
                return [[.dropdown(deviceOrientation, choices)]]
                
            case .plane:
                let plane = self.getPlane?.display ?? .empty
                let choices = Plane.choices
                return [[.dropdown(plane, choices)]]
                
            case .scrollMode:
                let scrollMode = self.getScrollMode?.display ?? .empty
                let choices = ScrollMode.choices
                return [[.dropdown(scrollMode, choices)]]
                
            case .lightType:
                let lightType = self.getLightType?.display ?? .empty
                let choices = LightType.choices
                return [[.dropdown(lightType, choices)]]
                
            case .networkRequestType:
                let networkRequestType = self.getNetworkRequestType?.display ?? .empty
                let choices = NetworkRequestType.choices
                return [[.dropdown(networkRequestType, choices)]]
                
            case .layerStroke:
                let layerStroke = self.getLayerStroke?.display ?? .empty
                let choices = LayerStroke.choices
                return [[.dropdown(layerStroke, choices)]]
                
            case .textTransform:
                let textTransform = self.getTextTransform?.display ?? .empty
                let choices = TextTransform.choices
                return [[.dropdown(textTransform, choices)]]
                
            case .dateAndTimeFormat:
                let dateAndTimeFormat = self.getDateAndTimeFormat?.display ?? .empty
                let choices = DateAndTimeFormat.choices
                return [[.dropdown(dateAndTimeFormat, choices)]]
                
            case .scrollJumpStyle:
                let scrollJumpStyle = self.getScrollJumpStyle?.display ?? .empty
                let choices = ScrollJumpStyle.choices
                return [[.dropdown(scrollJumpStyle, choices)]]
                
            case .scrollDecelerationRate:
                let scrollDecelerationRate = self.getScrollDecelerationRate?.display ?? .empty
                let choices = ScrollDecelerationRate.choices
                return [[.dropdown(scrollDecelerationRate, choices)]]
                
            case .delayStyle:
                let delayStyle = self.delayStyle?.rawValue ?? .empty
                let choices = DelayStyle.choices
                return [[.dropdown(delayStyle, choices)]]
                
            case .shapeCoordinates:
                let shapeCoordinates = self.getShapeCoordinates?.rawValue ?? .empty
                let choices = ShapeCoordinates.choices
                return [[.dropdown(shapeCoordinates, choices)]]
                
            case .shapeCommandType:
                let shapeCommandType = self.shapeCommandType?.display ?? .empty
                let choices = ShapeCommandType.choices
                return [[.dropdown(shapeCommandType, choices)]]
                
            case .orientation:
                let orientation = self.getOrientation?.display ?? .empty
                let choices = StitchOrientation.choices
                return [[.dropdown(orientation, choices)]]
                
            case .vnImageCropAndScale:
                let vnImageCropOption = self.vnImageCropOption?.label ?? .empty
                let choices = VNImageCropAndScaleOption.choices
                return [[.dropdown(vnImageCropOption, choices)]]
                
            case .mapType:
                let mapType = self.getMapType ?? .standard
                let choices = StitchMapType.choices
                return [[.dropdown(mapType.rawValue, choices)]]
                
            case .progressIndicatorStyle:
                let progressIndicatorStyle = self.getProgressIndicatorStyle ?? .circular
                let choices = ProgressIndicatorStyle.choices
                return [[.dropdown(progressIndicatorStyle.rawValue, choices)]]

            case .mobileHapticStyle:
                let mobileHapticStyle = self.getMobileHapticStyle ?? .heavy
                let choices = MobileHapticStyle.choices
                return [[.dropdown(mobileHapticStyle.rawValue, choices)]]
                
            case .strokeLineCap:
                let value = self.getStrokeLineCap ?? .defaultStrokeLineCap
                let choices = StrokeLineCap.choices
                return [[.dropdown(value.rawValue, choices)]]
                
            case .strokeLineJoin:
                let value = self.getStrokeLineJoin ?? .defaultStrokeLineJoin
                let choices = StrokeLineJoin.choices
                return [[.dropdown(value.rawValue, choices)]]
                
            case .contentMode:
                let value = self.getContentMode ?? .defaultContentMode
                return [[.dropdown(value.rawValue,
                                   StitchContentMode.choices)]]
                
            case .spacing:
                let value = self.getStitchSpacing ?? .defaultStitchSpacing
                return [[.dropdown(value.display,
                                   [.spacing(.evenly), .spacing(.between)])]]
            } // case .singleDropdown
            
        case .textFontDropdown:
            let textFont = self.getTextFont ?? .defaultStitchFont
            return [[.textFontDropdown(textFont)]]

        case .bool:
            let bool = self.getBool ?? self.comparableValue?.bool ?? false
            return [[.bool(bool)]]

        case .asyncMedia:
            var asyncMedia = self._asyncMedia
            var fieldValue: FieldValueMedia = .none
            
            // Check for imported media value, which doesn't hold media directly
            if let importedMedia = importedMediaObject {
                asyncMedia?._mediaObject = importedMedia
            }
            
            if let asyncMedia = asyncMedia,
               let media = GraphMediaValue(from: asyncMedia) {
                fieldValue = .media(media)
            }
            return [[.media(fieldValue)]]

        case .number:
            // if self is PortValue.comparable, then .getNumber will fail;
            // so we must also attempt to coerce to comparable-number
            let number = self.getNumber ?? self.comparableValue?.number ?? .zero
            return [[.number(number)]]

        case .string:
            let string = self.getString ?? self.comparableValue?.stitchStringValue ?? .init(.empty)
            return [[.string(string)]]

        case .layerDimension:
            let layerDimension = self.getLayerDimension ?? .number(.zero)
            return [[.layerDimension(layerDimension.fieldValue)]]

        case .pulse:
            let pulseTime = self.getPulse ?? .zero
            return [[.pulse(pulseTime)]]

        case .color:
            let color = self.getColor ?? falseColor
            return [[.color(color)]]

        case .json:
            let json = self.getStitchJSON ?? .emptyJSONObject
            return [[.json(json)]]

        case .assignedLayer:
            let layerId = self.getInteractionId
            return [[.layerDropdown(layerId)]]

        case .anchoring:
            let anchor = self.getAnchoring ?? .defaultAnchoring
            return [[.anchorPopover(anchor)]]

        case .readOnly:
            let display = self.display
            return [[.readOnly(display)]]
        }
    }
}

extension String {
    var isPercentageField: Bool {
        self.last == "%"
    }
}
