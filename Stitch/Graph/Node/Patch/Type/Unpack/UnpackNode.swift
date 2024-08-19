//
//  UnpackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/4/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import SceneKit
import RealityKit

/*
 Handles unpacking of:

 - .size: LayerSize input -> (height: LayerDimension, width: LayerDimension) outputs

 - .position: StitchPosition input -> (x: CGFloat, y: CGFloat) outputs

 - .point3D: Point3D input -> (x: CGFloat, y: CGFloat, z: CGFloat) outputs

 - .point4D: Point4D input -> (x: CGFloat, y: CGFloat, z: CGFloat, w: CGFloat) outputs

 - .matrix_float4x4: matrix_float4x4 input -> (Position X: Double, Position Y: Double, Position Z: Double, Scale X: Double, Scale Y: Double, Rotation X: Double, Rotation Y: Double, Rotation Z: Double) outputs

 */

// Defaults to nodeType = .size
struct UnpackPatchNode: PatchNodeDefinition {
    static let patch = Patch.unpack

    static let defaultUserVisibleType: UserVisibleType? = .size

    static var outputCountVariesByType: Bool = true

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: Self.rowInputsDefinitions(for: type),
            outputs: Self.rowOutputsDefinitions(for: type)
        )
    }

    static func rowInputsDefinitions(for type: UserVisibleType?) -> [NodeInputDefinition] {
        switch type {
        case .size:
            return [
                .init(label: "",
                      defaultType: .size)
            ]

        case .position:
            return [
                .init(label: "",
                      defaultType: .position)
            ]

        case .point3D:
            return [
                .init(label: "",
                      defaultType: .point3D)
            ]

        case .point4D:
            return [
                .init(label: "",
                      defaultType: .point4D)
            ]

        case .transform:
            return [
                .init(label: "",
                      defaultType: .transform)
            ]

        case .shapeCommand:
            return [
                .init(label: "",
                      defaultType: .shapeCommand)
            ]

        default:
            fatalErrorIfDebug()
            return []
        }
    }
    
    static func rowOutputsDefinitions(for type: UserVisibleType?) -> [NodeOutputDefinition] {
        switch type {
        case .size:
            return [
                .init(label: "W",
                      type: .number),
                .init(label: "H",
                      type: .number)
            ]

        case .position:
            return [
                .init(label: "X",
                      type: .number),
                .init(label: "Y",
                      type: .number)
            ]

        case .point3D:
            return [
                .init(label: "X",
                      type: .number),
                .init(label: "Y",
                      type: .number),
                .init(label: "Z",
                      type: .number)
            ]

        case .point4D:
            return [
                .init(label: "X",
                      type: .number),
                .init(label: "Y",
                      type: .number),
                .init(label: "Z",
                      type: .number),
                .init(label: "W",
                      type: .number)
            ]

        case .transform:
            return [
                .init(label: "Position X",
                      type: .number),
                .init(label: "Position Y",
                      type: .number),
                .init(label: "Position Z",
                      type: .number),
                .init(label: "Scale X",
                      type: .number),
                .init(label: "Scale Y",
                      type: .number),
                .init(label: "Scale Z",
                      type: .number),
                .init(label: "Rotation X",
                      type: .number),
                .init(label: "Rotation Y",
                      type: .number),
                .init(label: "Rotation Z",
                      type: .number)
            ]

        case .shapeCommand:
            return [
                .init(label: "Command Type",
                      type: .number),
                .init(label: "Point",
                      type: .number),
                .init(label: "Curve From",
                      type: .number),
                .init(label: "Curve To",
                      type: .number)
            ]

        default:
            fatalErrorIfDebug()
            return []
        }
    }
}

func sizeUnpackOp(values: PortValues) -> (PortValue, PortValue) {
    if let value = values.first, // only a single input
       let size: LayerSize = value.getSize {
        return (.layerDimension(size.width),
                .layerDimension(size.height))
    } else {
        fatalErrorIfDebug()
        return (.layerDimension(.number(.zero)),
                .layerDimension(.number(.zero)))
    }
}

func positionUnpackOp(values: PortValues) -> (PortValue, PortValue) {
    if let value = values.first, // only a single input
       let position = value.getPosition {
        return (.number(Double(position.width)),
                .number(Double(position.height)))
    } else {
        fatalErrorIfDebug()
        return (.number(.zero),
                .number(.zero))
    }
}

func point3DUnpackOp(values: PortValues) -> (PortValue, PortValue, PortValue) {
    if let value = values.first, // only one input port
       let point3D = value.getPoint3D {
        return (
            .number(Double(point3D.x)),
            .number(Double(point3D.y)),
            .number(Double(point3D.z))
        )
    } else {
        fatalErrorIfDebug()
        return (
            .number(.zero),
            .number(.zero),
            .number(.zero)
        )
    }
}

func point4DUnpackOp(values: PortValues) -> (PortValue, PortValue, PortValue, PortValue) {
    if let value = values.first, // only one input port
       let point4D = value.getPoint4D {
        return (
            .number(Double(point4D.x)),
            .number(Double(point4D.y)),
            .number(Double(point4D.z)),
            .number(Double(point4D.w))
        )
    } else {
        fatalErrorIfDebug()
        return (
            .number(.zero),
            .number(.zero),
            .number(.zero),
            .number(.zero)
        )
    }
}

func transformUnpackOp(values: PortValues) -> (PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue, PortValue) {
    if let value = values.first, // only one input port
       let transform = value.getTransform {
        return (
            .number(Double(transform.positionX)),
            .number(Double(transform.positionY)),
            .number(Double(transform.positionZ)),
            .number(Double(transform.scaleX)),
            .number(Double(transform.scaleY)),
            .number(Double(transform.scaleZ)),
            .number(Double(transform.rotationX)),
            .number(Double(transform.rotationY)),
            .number(Double(transform.rotationZ))
            
        )
    } else {
        fatalError("unpack matrix")
        return (
            .number(.zero),
            .number(.zero),
            .number(.zero),
            .number(.zero),
            .number(.zero),
            .number(.zero),
            .number(.zero),
            .number(.zero),
            .number(.zero)
        )
    }
}


let shapeCommandOp: Operation4 = { (values: PortValues) -> (PortValue, PortValue, PortValue, PortValue) in
    if let shapeCommand = values.first?.shapeCommand {
        return (
            .shapeCommandType(shapeCommand.getShapeCommandType),
            .position(shapeCommand.getPoint?.asCGSize ?? .zero),
            .position(shapeCommand.getCurveFrom?.asCGSize ?? .zero),
            .position(shapeCommand.getCurveTo?.asCGSize ?? .zero)
        )
    } else {
        fatalErrorIfDebug()
        let shapeCommand: ShapeCommand = .defaultFalseShapeCommand
        return (
            .shapeCommandType(shapeCommand.getShapeCommandType),
            .position(shapeCommand.getPoint?.asCGSize ?? .zero),
            .position(shapeCommand.getCurveFrom?.asCGSize ?? .zero),
            .position(shapeCommand.getCurveTo?.asCGSize ?? .zero)
        )
    }
}

func unpackEval(inputs: PortValuesList,
                outputs: PortValuesList) -> PortValuesList {

    //    log("unpackEval: inputs: \(inputs)")

    // TODO: switch to PackNodeType
    // If .size type, then returns two LayerDimension outputs.
    // Else two Number outputs.
    switch inputs.first!.first {
    case .size:
        return resultsMaker2(inputs)(sizeUnpackOp)
    case .position:
        return resultsMaker2(inputs)(positionUnpackOp)
    case .point3D:
        return resultsMaker3(inputs)(point3DUnpackOp)
    case .point4D:
        return resultsMaker4(inputs)(point4DUnpackOp)
    case .transform:
        return outputEvalHelper9(
            inputs: inputs,
            outputs: [],
            operation: transformUnpackOp)
    case .shapeCommand:
        return resultsMaker4(inputs)(shapeCommandOp)
    default:
        fatalError("unpackEval: wrong type")
    }
}

let SIZE_WIDTH_LABEL = "W"
let SIZE_HEIGHT_LABEL = "H"
let SIZE_LABELS = [SIZE_WIDTH_LABEL, SIZE_HEIGHT_LABEL]

let POSITION_X_LABEL = "X"
let POSITION_Y_LABEL = "Y"
let POSITION_Z_LABEL = "Z"
let POSITION_LABELS = [POSITION_X_LABEL, POSITION_Y_LABEL]

let POINT3D_X_LABEL = POSITION_X_LABEL
let POINT3D_Y_LABEL = POSITION_Y_LABEL
let POINT3D_Z_LABEL = "Z"

let POINT4D_W_LABEL = "W"

let SCALE_X_LABEL = "Scale X"
let SCALE_Y_LABEL = "Scale Y"
let SCALE_Z_LABEL = "Scale Z"

let POINT3D_LABELS = [
    POINT3D_X_LABEL,
    POINT3D_Y_LABEL,
    POINT3D_Z_LABEL
]

let POINT4D_LABELS = [
    POINT3D_X_LABEL,
    POINT3D_Y_LABEL,
    POINT3D_Z_LABEL,
    POINT4D_W_LABEL
]

let MATRIX_LABELS = [
    POSITION_X_LABEL,
    POSITION_Y_LABEL,
    POSITION_Z_LABEL,
    SCALE_X_LABEL,
    SCALE_Y_LABEL,
    SCALE_Z_LABEL
]
