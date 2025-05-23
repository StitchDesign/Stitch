//
//  Coercers.swift
//  prototype
//
//  Created by cjc on 2/12/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import CoreML
import SwiftyJSON

/* ----------------------------------------------------------------
 Coercers: any PortValue -> some expected PortValue case
 ---------------------------------------------------------------- */

// MARK: string coercison causes perf loss (GitHub issue #3120)
// extension Double {
//    var coerceToUserFriendlyString: String {
//        let fmt = NumberFormatter()
//        fmt.numberStyle = .decimal
//        // stops usage of comma separator which creates issues with editing later
//        fmt.groupingSeparator = .empty
//        fmt.maximumFractionDigits = 4
//
//        let numberString = fmt.string(for: self) ?? String(self)
//        return numberString
//    }
// }
//
// extension CGFloat {
//    var coerceToUserFriendlyString: String {
//        Double(self).coerceToUserFriendlyString
//    }
// }

// typealias Coerce = (PortValue) -> PortValue

// this is not quite correct?
// ... since boolParser just says "true" if the display string is non-empty,
// whereas really, "0" is non-empty but falsey
func boolCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    values.map { .bool($0.coerceToTruthyOrFalsey(graphTime)) }
}

// ie port is expected to be of type String;
// and so if a loop is passed in, coerce every loop index to type String;
func stringCoercer(_ values: PortValues) -> PortValues {
    
    values.enumerated().map { index, value in
        let defaultString = PortValue.string(.init(value.display))
        
        switch value {
            // Keep async media in case we have base 64 string
        case .string:
            return value
            //        case .json(let x):
            //            return x.value.coerceToPortValue(ofType: .string)
        default:
            return defaultString
        }
    }
}

// need a function like "PV is truthy, is false"
func pulseCoercer(_ values: PortValues,
                  graphTime: TimeInterval) -> PortValues {
    
    // if the incoming value is truthy,
    // then pulse = true;
    // else false
    
    //    log("pulseCoercer called")
    
    return values.map { (value: PortValue) -> PortValue in
        
        if let pulseAt = value.getPulse {
            //            log("pulseCoercer: had pulse: pulseAt: \(pulseAt)")
            return .pulse(pulseAt)
        } else if coerceToTruthyOrFalsey(value, graphTime: graphTime) {
            //            log("pulseCoercer: coerced value \(value) to true, will use graphTime")
            return .pulse(graphTime)
        } else {
            // this is COERCING non-pulse port-values to pulse port values...
            // For falsey pulse port values, use .zero
            //            log("pulseCoercer: default...")
            return .pulse(.zero)
        }
    }
}

// ADVANCED IMPLEMENTATIONS:
// - PortValues that do not have sensible .display
// - If new port value is already desired kind, then return;
//  ... else default to something sensible

extension Color {
    static func fromGrayscaleNumber(_ n: Double) -> Color {
        Color(white: n)
    }
}

extension PortValue {
    func asGrayscaleColor(graphTime: TimeInterval) -> Color {
        switch self {
        case .number(let n):
            return .fromGrayscaleNumber(n)
        case .layerDimension(let n):
            return .fromGrayscaleNumber(n.asNumber)
        case .size(let n):
            return .fromGrayscaleNumber(n.asAlgebraicCGSize.width)
        case .position(let n):
            return .fromGrayscaleNumber(n.x)
        case .point3D(let n):
            return .fromGrayscaleNumber(n.x)
        case .point4D(let n):
            return .fromGrayscaleNumber(n.x)
        case .string(let n):
            return .fromGrayscaleNumber(Double(n.string.count))
        default:
            return self.coerceToTruthyOrFalsey(graphTime) ? Color.trueColor : Color.falseColor
        }
    }
}

func colorCoercer(_ values: PortValues, graphTime: TimeInterval) -> PortValues {
    //    log("colorCoercer called")
    values.map {
        switch $0 {
        case .color:
            return $0 // color stays same
            //        case .json(let x):
            //            return x.value.coerceToPortValue(ofType: .color)
        default:
            return .color($0.asGrayscaleColor(graphTime: graphTime)) // all others, try to coerce to grayscale color
        }
    }
}

func transformCoercer(_ values: PortValues) -> PortValues {
    values.map { (value: PortValue) -> PortValue in
        switch value {
        case .transform(let x):
            return .transform(x)
            //        case .json(let x):
            //            return x.value.coerceToPortValue(ofType: .transform)
        default:
            return defaultTransform
        }
    }
}

func planeCoercer(_ values: PortValues) -> PortValues {
    values.map { (value: PortValue) -> PortValue in
        switch value {
        case .plane(let x):
            return .plane(x)
        case .number(let x):
            return Plane.fromNumber(x)
            //        case .json(let x):
            //            return x.value.coerceToPortValue(ofType: .plane)
        default:
            return defaultTransformAnchor
        }
    }
}

// most non-image values seem to be coerced to the empty/default image etc.
func asyncMediaCoercer(_ values: PortValues) -> PortValues {
    values.map { (value: PortValue) -> PortValue in
        switch value {
        case .asyncMedia(let x):
            return .asyncMedia(x)
        default:
            return .asyncMedia(nil)
        }
    }
}

func delayStyleCoercer(_ values: PortValues) -> PortValues {
    values.map { value in
        switch value {
        case .delayStyle(let x):
            return .delayStyle(x)
        case .number(let x):
            return DelayStyle.fromNumber(x)
            //        case .json(let x):
            //            return x.value.coerceToPortValue(ofType: .delayStyle)
        default:
            return .delayStyle(.always)
        }
    }
}

func shapeCoordinatesCoercer(_ values: PortValues) -> PortValues {
    values.map { value in
        switch value {
        case .shapeCoordinates(let x):
            return .shapeCoordinates(x)
        case .number(let x):
            return ShapeCoordinates.fromNumber(x)
            //        case .json(let x):
            //            return x.value.coerceToPortValue(ofType: .shapeCoordinates)
        default:
            return .shapeCoordinates(.relative)
        }
    }
}

// TODO?: Other types can be coerced into eg a single-element json array,
// or some complex port value types like position can be coerced to a json object?
func jsonCoercer(_ values: PortValues) -> PortValues {
    values.map { .json($0.coerceToHumanFriendlyJSON) }
}

func networkRequestTypeCoercer(_ values: PortValues) -> PortValues {
    values.map { (value: PortValue) -> PortValue in
        switch value {
        case .networkRequestType:
            return value
        case .number(let x):
            return NetworkRequestType.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.networkRequestType)
        default:
            return networkRequestTypeDefault
        }
    }
}

func interactionIdCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .assignedLayer:
            // log("interactionIdCoercer: interactionId")
            return $0
        case .none:
            return .assignedLayer(nil)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.interactionId)
        default:
            // log("interactionIdCoercer: default")
            return .assignedLayer(nil)
        }
    }
}

func pinToCoercer(_ values: PortValues) -> PortValues {
    // log("pinToCoercer: values: \(values)")
    let defaultValue = PortValue.pinTo(.defaultPinToId)
    return values.map {
        switch $0 {
        case .pinTo:
            // log("pinToCoercer: pinTo")
            return $0
        case .assignedLayer(let x):
            // log("pinToCoercer: assignedLayer \(x)")
            if let x = x {
                return .pinTo(.layer(x))
            } else {
                return defaultValue
            }
        case .json(let x):
            return x.value.coerceJSONToPortValue(.pinToId)
        default:
            // log("pinToCoercer: default")
            return defaultValue
        }
    }
}

func deviceAppearanceCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .deviceAppearance:
            return $0
        case .number(let x):
            return DeviceAppearance.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.deviceAppearance)
        default:
            return .deviceAppearance(DeviceAppearance.defaultDeviceAppearance)
        }
    }
}

func materialThicknessCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .materialThickness:
            return $0
        case .number(let x):
            return MaterialThickness.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.materialThickness)
        default:
            return .materialThickness(MaterialThickness.defaultMaterialThickness)
        }
    }
}

func scrollModeCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .scrollMode:
            return $0
        case .number(let x):
            return ScrollMode.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.scrollMode)
        default:
            return scrollModeDefault
        }
    }
}

func textAlignmentCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .textAlignment:
            return $0
        case .number(let x):
            return LayerTextAlignment.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.textAlignment)
        default:
            return defaultTextAlignment
        }
    }
}

func textVerticalAlignmentCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .textVerticalAlignment:
            return $0
        case .number(let x):
            return LayerTextVerticalAlignment.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.textVerticalAlignment)
        default:
            return defaultTextVerticalAlignment
        }
    }
}

func textDecorationCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .textDecoration:
            return $0
        case .number(let x):
            return LayerTextDecoration.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.textDecoration)
        default:
            return .textDecoration(.defaultLayerTextDecoration)
        }
    }
}

func textFontCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .textFont:
            return $0
        case .json(let x):
            return x.value.coerceJSONToPortValue(.textFont)
        default:
            return defaultStitchFontPortValue
        }
    }
}

extension PortValue {
    // Takes any PortValue, and returns a StitchBlendMode
    func coerceToBlendMode() -> StitchBlendMode {
        switch self {
        case .blendMode(let x):
            return x
        case .number(let x):
            return StitchBlendMode.fromNumber(x).getBlendMode ?? .defaultBlendMode
        case .json(let x):
            return x.value.coerceJSONToPortValue(.blendMode).getBlendMode ?? .defaultBlendMode
        default:
            return .defaultBlendMode
        }
    }
}

func blendModeCoercer(_ values: PortValues) -> PortValues {
    values
        .map { $0.coerceToBlendMode() }
        .map(PortValue.blendMode)
}

func fitStyleCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .fitStyle:
            return $0
        case .number(let x):
            return VisualMediaFitStyle.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.fitStyle)
        default:
            return VisualMediaFitStyle.defaultMediaFitStylePortValue
        }
    }
}

func animationCurveCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .animationCurve:
            return $0
        case .number(let x):
            return ClassicAnimationCurve.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.animationCurve)
        default:
            return .animationCurve(defaultAnimationCurve)
        }
    }
}

func lightTypeCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .lightType:
            return $0
        case .number(let x):
            return LightType.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.lightType)
        default:
            return .lightType(defaultLightType)
        }
    }
}

func layerStrokeCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .layerStroke:
            return $0
        case .number(let x):
            return LayerStroke.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.layerStroke)
        default:
            return .layerStroke(.defaultStroke)
        }
    }
}

func textTransformCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .textTransform:
            return $0
        case .number(let x):
            return TextTransform.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.textTransform)
        default:
            return .textTransform(.defaultTransform)
        }
    }
}

func dateAndTimeFormatCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .dateAndTimeFormat:
            return $0
        case .number(let x):
            return DateAndTimeFormat.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.dateAndTimeFormat)
        default:
            return .dateAndTimeFormat(.defaultFormat)
        }
    }
}

// LayerGroup orientation
func orientationCoercer(_ values: PortValues) -> PortValues {
    values.map { value in
        switch value {
        case .orientation:
            return value
        case .number(let x):
            return StitchOrientation.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.orientation)
        default:
            return .orientation(.defaultOrientation)
        }
    }
}

// TODO: probably a good pattern to use for all our coercers?
extension PortValue {
    var toCameraOrientation: StitchCameraOrientation {
        switch self {
        case .deviceOrientation(let x):
            return x.toStitchCameraOrientation
        case .cameraOrientation(let x):
            return x
        case .number(let x):
            // Is `.portrait` not quite correct?
            return StitchCameraOrientation.fromNumber(x).getCameraOrientation ?? .portrait
        case .json(let x):
            return x.value.coerceJSONToPortValue(.cameraOrientation).getCameraOrientation ?? .portrait
        default:
            return .portrait
        }
    }
}

/*
 If we changed the camera orientation or direction on a camera feed node,
 we must also update the graph's underlying single camera (CameraSettings).
 
 NOTE: changing e.g. the camera orientation on e.g. a value node does NOT require us to immediately change the graph's underlying single camera,
 since the value node may not have any downstream connections.
 
 HOWEVER, to avoid having to do a "nodeSchema.kind == .cameraFeed" check everytime we coerceUpdate ANY PortValue, we move that check logic to the actual `CameraOrientationUpdated` action.
 */
func cameraOrientationCoercer(_ values: PortValues) -> PortValues {
    values.map(\.toCameraOrientation).map(PortValue.cameraOrientation)
}

// TODO: probably a good pattern to use for all our coercers?
extension PortValue {
    var toCameraDirection: CameraDirection {
        switch self {
        case .cameraDirection(let x):
            return x
        case .number(let x):
            return CameraDirection.fromNumber(x).getCameraDirection ?? .defaultCameraDirection
        case .json(let x):
            return x.value.coerceJSONToPortValue(.cameraDirection).getCameraDirection ?? .defaultCameraDirection
        default:
            return .defaultCameraDirection
        }
    }
}

func cameraDirectionCoercer(_ values: PortValues) -> PortValues {
    values.map(\.toCameraDirection).map(PortValue.cameraDirection)
}

func deviceOrientationCoercer(_ values: PortValues) -> PortValues {
    values.map { value in
        switch value {
        case .deviceOrientation:
            return value
        case .cameraOrientation(let x):
            return .deviceOrientation(x.toStitchDeviceOrientation)
        case .number(let x):
            return StitchDeviceOrientation.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.deviceOrientation)
        default:
            return .deviceOrientation(.defaultDeviceOrientation)
        }
    }
}

func shapeCommandCoercer(_ values: PortValues) -> PortValues {
    
    values.map { value in
        switch value {
        case .shapeCommand:
            return value
            
            // TODO: this logic is handled via `Shape to Commands` node; do we also want to handle it here?
            // If we received a Shape,
            // just take the first part as a ShapeCommand
            //        case .shape(let x):
            //            if let shapeCommand = x?.toShapeCommand {
            //                return .shapeCommand(shapeCommand)
            //            }
            //            return .shapeCommand(.defaultFalseShapeCommand)
            //        case .json(let x):
            //            return x.value.coerceToPortValue(ofType: .shapeCommand)
        default:
            return .shapeCommand(.defaultFalseShapeCommand)
        }
    }
}

// TODO: any coercion to a command type means we need to do the full recalc of the node and graph, something not currently supported by coercers alone.
// see https://github.com/vpl-codesign/stitch/issues/2991#issuecomment-1546477479
// func shapeCommandTypeCoercer(_ values: PortValues) -> PortValues {
func shapeCommandTypeCoercer(_ oldValue: PortValue,
                             _ values: PortValues) -> PortValues {
    
    //    let defaultReturn = PortValue.shapeCommandType(.defaultFalseShapeCommandType)
    
    return values.map { value in
        switch value {
            
        default:
            // for now we ignore all coercion:
            // *no* incoming value can change a command-type dropdown input.
            // We always return the oldValue.
            return oldValue
            
            //        case .shapeCommandType:
            //            return value
            //        case .shapeCommand(let x):
            //            return .shapeCommandType(x.getShapeCommandType)
            //        case .string(let x):
            //            if let command = ShapeCommandType(rawValue: x) {
            //                return .shapeCommandType(command)
            //            } else {
            //                // if we can't coerce the string to a command-type,
            //                // then just keep the current command-type.
            //                return value
            //            }
            //        default:
            //            return defaultReturn
        }
    }
}

// TODO: If we receive a loop of shape commands,
// should we coerce those into a single shape?
// Or should that logic be only done in `Commands To Shape` node?
// We want this logic for a Shape layer node's shape input,
// but currently can't choose behavior based on layer/patch.
func shapeCoercer(_ values: PortValues) -> PortValues {
    
    // Slightly awkward when we return a loop into a scalar;
    // e.g. we have a loop edge going into a shape input whose color looks scalar...
    //    if let jsonCommands = values.compactMap(\.shapeCommand).asJSONShapeCommands {
    //        return [.shape(.init(.custom(jsonCommands)))]
    //    }
    
    return values.map {
        switch $0 {
        case .shape:
            return $0
            
            // TODO: do we want to allow this or not?
        case .json(let json):
            
            // NOTE: Assumes coordinate space of (1,1) and throws away error;
            // Compare with actual `JSON to Shape` patch node
            
            //            if let commands = json.value.parseAsJSONShapeCommands().getCommands {
            //                let parsedShape = CustomShape(.custom(commands))
            //                return .shape(parsedShape)
            //            } else {
            //                return .shape(nil)
            //            }
            
            return .shape(json.value.coerceToCustomShape)
            
        default:
            return .shape(nil)
        }
    }
}

extension JSON {
    var coerceToCustomShape: CustomShape? {
        if let commands = self.parseAsPathCommands()?.asJSONShapeCommands {
            let parsedShape = CustomShape(.custom(commands))
            return parsedShape
        } else {
            return nil
        }
        
    }
}

func scrollJumpStyleCoercer(_ values: PortValues) -> PortValues {
    return values.map {
        switch $0 {
        case .scrollJumpStyle:
            return $0
        case .number(let x):
            return ScrollJumpStyle.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.scrollJumpStyle)
        default:
            return .scrollJumpStyle(.scrollJumpStyleDefault)
        }
    }
}

func scrollDecelerationRateCoercer(_ values: PortValues) -> PortValues {
    return values.map {
        switch $0 {
        case .scrollDecelerationRate:
            return $0
        case .number(let x):
            return ScrollDecelerationRate.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.scrollDecelerationRate)
        default:
            return .scrollDecelerationRate(.scrollDecelerationRateDefault)
        }
    }
}

func vnImageCropCoercer(_ values: PortValues) -> PortValues {
    values.map {
        switch $0 {
        case .vnImageCropOption:
            return $0
            // TODO: trickier since the associated-value for this PortValue is a type we don't own and which doesn't implement PortValueEnum
            //        case .number(let x):
            //            return VNIma.fromNumber(x)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.vnImageCropOption)
        default:
            return .vnImageCropOption(.scaleFill)
        }
    }
}

func anchoringCoercer(_ values: PortValues) -> PortValues {
    return values.map { (value: PortValue) -> PortValue in
        switch value {
        case .anchoring:
            //                log("anchoringCoercer: value: \(value)")
            return value
        case .number(let x):
            //            return Anchoring.fromNumber(x)
            return portValueEnumCase(from: Int(x),
                                     with: Anchoring.choices)
        case .json(let x):
            return x.value.coerceJSONToPortValue(.anchoring)
        default:
            // Origami seems to default to first couple anchorings;
            // Origami does not parse a
            return .anchoring(.defaultAnchoring)
        }
    }
}

func comparableCoercer(_ values: PortValues) -> PortValues {
    values.map { value in
        switch value {
        case .comparable:
            return value
        case .number(let x):
            return .comparable(.number(x))
        case .bool(let x):
            return .comparable(.bool(x))
        case .string(let x):
            return .comparable(.string(x))
        case .layerDimension(let x):
            return .comparable(.number(x.asNumber))
        case .shapeCommandType(let x):
            return .comparable(.string(.init(x.rawValue)))
        case .shapeCommand(let x):
            // Don't turn it into a JSON
            return .comparable(.string(.init(x.asDictionaryString)))
        default:
            return.comparable(nil)
        }
    }
}

extension PortValue {
    // Takes any PortValue, and returns a MobileHapticStyle
    func coerceToContentMode() -> StitchContentMode {
        switch self {
        case .contentMode(let x):
            return x
        case .number(let x):
            return StitchContentMode.fromNumber(x)
                .getContentMode ?? .defaultContentMode
        case .json(let x):
            return x.value.coerceJSONToPortValue(.contentMode).getContentMode ?? .defaultContentMode
        default:
            return .defaultContentMode
        }
    }
}

func contentModeCoercer(_ values: PortValues) -> PortValues {
    values.map { .contentMode($0.coerceToContentMode()) }
}

extension PortValue {
    // Takes any PortValue, and returns a MobileHapticStyle
    func coerceToSizingScenario() -> SizingScenario {
        switch self {
        case .sizingScenario(let x):
            return x
        case .number(let x):
            return SizingScenario.fromNumber(x)
                .getSizingScenario ?? .defaultSizingScenario
        case .json(let x):
            return x.value.coerceJSONToPortValue(.sizingScenario).getSizingScenario ?? .defaultSizingScenario
        default:
            return .defaultSizingScenario
        }
    }
}

func sizingScenarioCoercer(_ values: PortValues) -> PortValues {
    values.map { .sizingScenario($0.coerceToSizingScenario()) }
}

extension PortValues {
    func anchorEntityCoercer(values: PortValues) -> Self {
        values.map {
            switch $0 {
            case .anchorEntity:
                return $0
            default:
                return .anchorEntity(nil)
            }
        }
    }
}
