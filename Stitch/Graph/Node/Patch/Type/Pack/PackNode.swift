//
//  PackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/4/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import RealityKit

// combination of Size and Point3D nodes
// starts out as .size
struct PackPatchNode: PatchNodeDefinition {
    static let patch = Patch.pack

    static let defaultUserVisibleType: UserVisibleType? = .size

    static var inputCountVariesByType: Bool = true

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        Self.rowDefinitions(nodeType: type,
                            rowType: nil)
    }

    static func rowDefinitions(nodeType: UserVisibleType?,
                               rowType: NodeRowType?) -> NodeRowDefinitions {
        .init(
            inputs: Self.rowInputsDefinitions(nodeType: nodeType,
                                              rowType: rowType),
            outputs: [
                .init(
                    label: "",
                    type: nodeType ?? .size
                )
            ]
        )
    }

    static func rowInputsDefinitions(nodeType: UserVisibleType?,
                                     rowType: NodeRowType?) -> [NodeInputDefinition] {
        switch nodeType {
        case .size:
            return [
                .init(
                    label: "W",
                    staticType: .layerDimension
                ),
                .init(
                    label: "H",
                    staticType: .layerDimension
                )
            ]

        case .position:
            return [
                .init(
                    label: "X",
                    staticType: .number
                ),
                .init(
                    label: "Y",
                    staticType: .number
                )
            ]

        case .point3D:
            return [
                .init(label: "X",
                      staticType: .number),
                .init(label: "Y",
                      staticType: .number),
                .init(label: "Z",
                      staticType: .number)
            ]

        case .point4D:
            return [
                .init(label: "X",
                      staticType: .number),
                .init(label: "Y",
                      staticType: .number),
                .init(label: "Z",
                      staticType: .number),
                .init(label: "W",
                      staticType: .number)
            ]

        case .matrixTransform:
            let inputMatrix = DEFAULT_TRANSFORM_MATRIX_MODEL
            return [
                .init(defaultValues: [.number(Double(inputMatrix.position.x))],
                      label: "Position X",
                      isTypeStatic: true),
                .init(defaultValues: [.number(Double(inputMatrix.position.y))],
                      label: "Position Y",
                      isTypeStatic: true),
                .init(defaultValues: [.number(Double(inputMatrix.position.z))],
                      label: "Position Z",
                      isTypeStatic: true),
                .init(defaultValues: [.number(Double(inputMatrix.scale.x))],
                      label: "Scale X",
                      isTypeStatic: true),
                .init(defaultValues: [.number(Double(inputMatrix.scale.y))],
                      label: "Scale Y",
                      isTypeStatic: true),
                .init(defaultValues: [.number(Double(inputMatrix.scale.z))],
                      label: "Scale Z",
                      isTypeStatic: true),
                .init(defaultValues: [.number(Double(inputMatrix.rotation.imag.x))],
                      label: "Rotation X",
                      isTypeStatic: true),
                .init(defaultValues: [.number(Double(inputMatrix.rotation.imag.y))],
                      label: "Rotation Y",
                      isTypeStatic: true),
                .init(defaultValues: [.number(Double(inputMatrix.rotation.imag.z))],
                      label: "Rotation Z",
                      isTypeStatic: true),
                .init(defaultValues: [.number(Double(inputMatrix.rotation.real))],
                      label: "Rotation Real",
                      isTypeStatic: true)
            ]

        case .shapeCommand:
            // Default case
            let closePath: [NodeInputDefinition] = [
                .init(defaultValues: [.shapeCommand(.closePath)],
                      label: "Command Type",
                      isTypeStatic: true)
            ]

            switch rowType {
            case .shapeCommand(let shapeCommandFieldType):
                // Not supporting right now
                #if DEBUG
                fatalError()
                #endif
                return []
            //                switch shapeCommandFieldType {
            //                case .closePath:
            //                    return closePath
            //                case .lineTo:
            //                    return [
            //                        .init(defaultValues: [.shapeCommand(.lineTo(point: .zero))],
            //                              label: "Command Type",
            //                              isTypeStatic: true),
            //                        .init(defaultValues: [.position(.zero)],
            //                              label: "Point")
            //                    ]
            //                case .curveTo:
            //                    return [
            //                        .init(defaultValues: [.shapeCommand(.lineTo(point: .zero))],
            //                              label: "Command Type",
            //                              isTypeStatic: true),
            //                        .init(defaultValues: [.position(.zero)],
            //                              label: "Point"),
            //                        .init(defaultValues: [.position(.zero)],
            //                              label: "Curve From"),
            //                        .init(defaultValues: [.position(.zero)],
            //                              label: "Curve To")
            //                    ]
            //
            //                case .output:
            //                    // Not expected here
            //                    #if DEBUG
            //                    fatalError()
            //                    #endif
            //                    return []
            //                }

            default:
                // Called when values haven't been coerced yet
                return closePath
            }

        default:
            // Not expected here
            #if DEBUG
            fatalError()
            #endif
            return []
        }
    }
}

func packMatrixTransformInputs(id: NodeId,
                               inputMatrix: Transform) -> Inputs {
    toInputs(
        id: id,
        values:
            ("Position X", [.number(Double(inputMatrix.position.x))]),
        ("Position Y", [.number(Double(inputMatrix.position.y))]),
        ("Position Z", [.number(Double(inputMatrix.position.z))]),
        ("Scale X", [.number(Double(inputMatrix.scale.x))]),
        ("Scale Y", [.number(Double(inputMatrix.scale.y))]),
        ("Scale Z", [.number(Double(inputMatrix.scale.z))]),
        ("Rotation X", [.number(Double(inputMatrix.rotation.imag.x))]),
        ("Rotation Y", [.number(Double(inputMatrix.rotation.imag.y))]),
        ("Rotation Z", [.number(Double(inputMatrix.rotation.imag.z))]),
        ("Rotation Real", [.number(Double(inputMatrix.rotation.real))])
    )
}

func sizePackOp(values: PortValues) -> PortValue {
    .size(LayerSize.fromSizeNodeInputs(values))
}

func positionPackOp(values: PortValues) -> PortValue {
    .position(StitchPosition.fromSizeNodeInputs(values))
}

func point3DPackOp(values: PortValues) -> PortValue {
    if values.count == 3,
       let x = values[PackNodeLocations.x].getNumber,
       let y = values[PackNodeLocations.y].getNumber,
       let z = values[PackNodeLocations.z].getNumber {
        return .point3D(Point3D(x: x, y: y, z: z))
    } else {
        #if DEV || DEV_DEBUG
        fatalError()
        #endif
        return .point3D(.zero)
    }
}

func point4DPackOp(values: PortValues) -> PortValue {
    if values.count == 4,
       let x = values[PackNodeLocations.x].getNumber,
       let y = values[PackNodeLocations.y].getNumber,
       let z = values[PackNodeLocations.z].getNumber,
       let w = values[PackNodeLocations.w].getNumber {
        return .point4D(Point4D(x: x, y: y, z: z, w: w))
    } else {
        #if DEV || DEV_DEBUG
        fatalError()
        #endif
        return .point4D(.zero)
    }
}

func matrixPackOp(values: PortValues) -> PortValue {
    if let x = values[safe: PackNodeMatrixLocations.x]?.getNumber,
       let y = values[safe: PackNodeMatrixLocations.y]?.getNumber,
       let z = values[safe: PackNodeMatrixLocations.z]?.getNumber,
       let scaleX = values[safe: PackNodeMatrixLocations.scaleX]?.getNumber,
       let scaleY = values[safe: PackNodeMatrixLocations.scaleY]?.getNumber,
       let scaleZ = values[safe: PackNodeMatrixLocations.scaleZ]?.getNumber,
       let quatX = values[safe: PackNodeMatrixLocations.rotationX]?.getNumber,
       let quatY = values[safe: PackNodeMatrixLocations.rotationY]?.getNumber,
       let quatZ = values[safe: PackNodeMatrixLocations.rotationZ]?.getNumber,
       let quatW = values[safe: PackNodeMatrixLocations.rotationReal]?.getNumber {
        return .matrixTransform(Transform.createMatrix(positionX: Float(x), positionY: Float(y), positionZ: Float(z), scaleX: Float(scaleX), scaleY: Float(scaleY), scaleZ: Float(scaleZ), rotationX: Float(quatX), rotationY: Float(quatY), rotationZ: Float(quatZ), rotationReal: Float(quatW)).matrix)
    } else {
        #if DEV_DEBUG
        fatalError("matrixEvaluation")
        #endif
        return defaultTransformAnchor
    }
}

func packEval(inputs: PortValuesList,
              outputs: PortValuesList) -> PortValuesList {

    let shapeCommandOp: Operation = { (values: PortValues) -> PortValue in

        let defaultResult = PortValue.shapeCommand(.defaultFalseShapeCommand)

        if let commandType: ShapeCommandType = values.first?.shapeCommandType {

            // If we had command type but not point,
            // then we had a .closePath
            guard let point = values[safeIndex: PackNodeShapeCommandLocations.point]?.getPosition else {
                return .shapeCommand(.closePath)
            }

            // If we had point but not curveFrom and curveTo,
            // then we had a .lineTo or .moveTo
            guard let curveFrom = values[safeIndex: PackNodeShapeCommandLocations.curveFrom]?.getPosition,
                  let curveTo = values[safeIndex: PackNodeShapeCommandLocations.curveTo]?.getPosition else {

                if commandType == .lineTo {
                    return .shapeCommand(.lineTo(point: point.toPathPoint))
                } else if commandType == .moveTo {
                    return .shapeCommand(.moveTo(point: point.toPathPoint))
                } else {
                    return defaultResult
                }
            }

            // If we had all three, then we can make a curveTo
            return .shapeCommand(.curveTo(curveFrom: curveFrom.toPathPoint,
                                          point: point.toPathPoint,
                                          curveTo: curveTo.toPathPoint))

        }
        return defaultResult
    } // shapeCommandOp

    // Why were we looking at the number of inputs? ... Should be determinable

    let result = resultsMaker(inputs)

    let presumedNodeType = inputs.first!.first
    let inputCount = inputs.count

    // TODO: switch to PackNodeType; should switch on PackNodeType and not input count
    switch (presumedNodeType, inputCount) {

    case (.layerDimension, _):
        // .layerDimension inputs means nodeType == .size
        return result(sizePackOp)
    case (.number, 2):
        // .number inputs means nodeType == .position or .point3D
        return result(positionPackOp)
    case (.number, 3):
        return result(point3DPackOp)
    case (.number, 4):
        return result(point4DPackOp)
    case (.number, 10):
        return result(matrixPackOp)
    case (.shapeCommandType, _):
        return result(shapeCommandOp)
    default:
        #if DEV_DEBUG
        fatalError("Pack eval: wrong type or input count")
        #endif
        return outputs
    }
}
