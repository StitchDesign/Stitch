//
//  UnpackNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/4/22.
//

import Foundation
import SwiftUI

/*
 Handles unpacking of:

 - .size: LayerSize input -> (height: LayerDimension, width: LayerDimension) outputs

 - .position: StitchPosition input -> (x: CGFloat, y: CGFloat) outputs

 - .point3D: Point3D input -> (x: CGFloat, y: CGFloat, z: CGFloat) outputs
 */

// Defaults to nodeType = .size
func unpackPatchNode(id: NodeId,
                     x: Double = .zero,
                     y: Double = .zero,
                     z: Double = .zero,
                     w: Double = .zero,
                     position: CGSize = .zero,
                     zIndex: Double = 0,
                     // existingInputValue and nodeType
                     // must be coordinated...
                     existingInputValue: PortValue? = nil,
                     nodeType: UserVisibleType = .size) -> PatchNode {

    var inputSize: LayerSize = LayerSize(width: x, height: y)
    var inputPosition: StitchPosition = StitchPosition(width: x, height: y)
    var inputPoint3D: Point3D = Point3D(x: x, y: y, z: z)
    var inputPoint4D: Point4D = Point4D(x: x, y: y, z: z, w: w)

    if let value = existingInputValue {
        switch value {
        case .size(let k):
            inputSize = k
        case .position(let k):
            inputPosition = k
        case .point3D(let k):
            inputPoint3D = k
        case .point4D(let k):
            inputPoint4D = k
        default:
            fatalError()
        }
    }

    // unpackNode always has a single input
    let inputsCount = 1

    let makeInputs = { (initialValue: PortValue) in
        toInputs(
            id: id,
            // .size, .position, .point3D are multifield values;
            // each field has its own label, handled in UI.
            values: (nil, [initialValue]))
    }

    var inputs: Inputs
    var outputs: Outputs

    switch nodeType {
    case .size:
        inputs = makeInputs(.size(inputSize))
        outputs = unpackSizeOutputs(
            id: id,
            inputsCount: inputsCount,
            inputSize: inputSize)
    case .position:
        inputs = makeInputs(.position(inputPosition))
        outputs = unpackPositionOutputs(
            id: id,
            inputsCount: inputsCount,
            inputPosition: inputPosition)
    case .point3D:
        inputs = makeInputs(.point3D(inputPoint3D))
        outputs = unpackPoint3DOutputs(
            id: id,
            inputsCount: inputsCount,
            inputPoint3D: inputPoint3D)
    case .point4D:
        inputs = makeInputs(.point4D(inputPoint4D))
        outputs = unpackPoint4DOutputs(
            id: id,
            inputsCount: inputsCount,
            inputPoint4D: inputPoint4D)
    default:
        fatalError("unpackPatchNode: bad node type passed in")
    }

    return PatchNode(
        position: position,
        previousPosition: position,
        zIndex: zIndex,
        id: id,
        patchName: .unpack,
        // .size, .position, .point3D, .point4D
        userVisibleType: nodeType,
        inputs: inputs,
        outputs: outputs)
}

func unpackSizeOutputs(id: NodeId,
                       inputsCount: Int,
                       inputSize: LayerSize) -> Outputs {
    toOutputs(
        id: id,
        offset: inputsCount,
        values:
            ("W", [.layerDimension(inputSize.width)]),
        ("H", [.layerDimension(inputSize.height)]))
}

func unpackPositionOutputs(id: NodeId,
                           inputsCount: Int,
                           inputPosition: StitchPosition) -> Outputs {
    toOutputs(
        id: id,
        offset: inputsCount,
        values:
            ("X", [.number(inputPosition.width)]),
        ("Y", [.number(inputPosition.height)]))
}

func unpackPoint3DOutputs(id: NodeId,
                          inputsCount: Int,
                          inputPoint3D: Point3D) -> Outputs {
    toOutputs(
        id: id,
        offset: inputsCount,
        values:
            ("X", [.number(inputPoint3D.x)]),
        ("Y", [.number(inputPoint3D.y)]),
        ("Z", [.number(inputPoint3D.z)])
    )
}

func unpackPoint4DOutputs(id: NodeId,
                          inputsCount: Int,
                          inputPoint4D: Point4D) -> Outputs {
    toOutputs(
        id: id,
        offset: inputsCount,
        values:
            ("X", [.number(inputPoint4D.x)]),
        ("Y", [.number(inputPoint4D.y)]),
        ("Z", [.number(inputPoint4D.z)]),
        ("W", [.number(inputPoint4D.w)])
    )
}

func unpackEval(inputs: PortValuesList,
                outputs: PortValuesList) -> PortValuesList {

    //    log("unpackEval: inputs: \(inputs)")

    let sizeOp: Operation2 = { (values: PortValues) -> (PortValue, PortValue) in
        let value = values.first! // only a single input
        if let size: LayerSize = value.getSize {
            return (.layerDimension(size.width),
                    .layerDimension(size.height))
        } else {
            fatalError()
        }
    }

    let positionOp: Operation2 = { (values: PortValues) -> (PortValue, PortValue) in
        let value = values.first! // only a single input
        if let position = value.getPosition {
            return (.number(Double(position.width)),
                    .number(Double(position.height)))
        } else {
            fatalError()
        }
    }

    let point3DOp: Operation3 = { (values: PortValues) -> (PortValue, PortValue, PortValue) in
        let value = values.first! // only one input port
        if let point3D = value.getPoint3D {
            return (
                .number(Double(point3D.x)),
                .number(Double(point3D.y)),
                .number(Double(point3D.z))
            )
        } else {
            fatalError("unpack point3D")
        }
    }

    let point4DOp: Operation4 = { (values: PortValues) -> (PortValue, PortValue, PortValue, PortValue) in
        let value = values.first! // only one input port
        if let point4D = value.getPoint4D {
            return (
                .number(Double(point4D.x)),
                .number(Double(point4D.y)),
                .number(Double(point4D.z)),
                .number(Double(point4D.w))
            )
        } else {
            fatalError("unpack point4D")
        }
    }

    let result = { (op: Operation2) -> PortValuesList in
        outputEvalHelper2(inputs: inputs, operation: op)
    }

    // TODO: switch to PackNodeType
    // If .size type, then returns two LayerDimension outputs.
    // Else two Number outputs.
    switch inputs.first!.first {
    case .size:
        return result(sizeOp)
    case .position:
        return result(positionOp)
    case .point3D:
        return outputEvalHelper3(
            inputs: inputs,
            operation: point3DOp)
    case .point4D:
        return outputEvalHelper4(
            inputs: inputs,
            operation: point4DOp)
    default:
        fatalError("unpackEval: wrong type")
    }
}

// When changing the type of a Unpack node:
// size -> position: each .layerDimension input -> .number input
// position -> size: each .number input -> .layerDimension input
func unpackNodeTypeChange(node: PatchNode,
                          newNodeType: UserVisibleType,
                          graphTime: TimeInterval) -> PatchNode {
    var node = node

    let currentNodeType = node.userVisibleType!

    // Can you instead here just re-use the unpackNode fn?
    // eg recreate the node, with the existing data

    // e.g. if old type was position, and new type is point4D,
    // then do

    // Convert the current input to the new, expected type
    var currentInput: PortValues = node.sortedInputsValues.first!
    log("Unpack node: currentInput was: \(currentInput)")

    if let kind: PackNodeType = node.patchName.userTypeChoices.asPack(newNodeType) {
        switch kind {
        case .size:
            currentInput = sizeCoercer(currentInput)
        case .position:
            currentInput = positionCoercer(currentInput)
        case .point3D:
            currentInput = point3DCoercer(currentInput)
        case .point4D:
            currentInput = point4DCoercer(currentInput)
        }
    } else {
        log("Unpack node: could not change type", .logToServer)
        return node
    }

    log("Unpack node: currentInput is now: \(currentInput)")

    // unpack node doesn't have any internal state etc.
    let convertedNode = unpackPatchNode(id: node.id,
                                        // preserve position and z-index on graph
                                        position: node.position,
                                        zIndex: node.zIndex,
                                        // use the values that were coerced to the new type
                                        existingInputValue: currentInput.first!,
                                        // existingInputValue: node.sortedInputsValues.first!.first!,
                                        // use new node type;
                                        nodeType: newNodeType)

    log("Unpack node: convertedNode.sortedInputs: \(convertedNode.sortedInputs)")
    log("Unpack node: convertedNode.sortedOutputs: \(convertedNode.sortedOutputs)")

    return convertedNode

    let usesTwoOutputs = { (nodeType: UserVisibleType) in
        (nodeType == .size || nodeType == .position)
    }

    let usesThreeOutputs = { (nodeType: UserVisibleType) in
        nodeType == .point3D
    }

    let usesFourOutputs = { (nodeType: UserVisibleType) in
        nodeType == .point4D
    }

    // ADDING INPUTS
    // add 1
    let fromPositionToPoint3D = usesTwoOutputs(currentNodeType) && usesThreeOutputs(newNodeType)
    // add 2
    let fromPositionToPoint4D = usesTwoOutputs(currentNodeType) && usesFourOutputs(newNodeType)
    // add 1
    let fromPoint3DToPoint4D = usesThreeOutputs(currentNodeType) && usesFourOutputs(newNodeType)

    // From 2 -> 3 outputs
    // i.e. position/size -> point3D
    if usesTwoOutputs(currentNodeType) && (usesThreeOutputs(newNodeType) || usesFourOutputs(newNodeType)) {
        log("unpackNodeTypeChange: add input")
        // add an input
        var outputs = node.sortedOutputs
        assert(outputs.count == 2)
        outputs.append(Output(coordinate: OutputCoordinate(portId: 3, // 4rd port, including inputs
                                                           nodeId: node.id),
                              label: POINT3D_Z_LABEL,
                              values: [.number(.zero)]))

        if usesFourOutputs(newNodeType) {
            outputs.append(Output(coordinate: OutputCoordinate(portId: 4, // 5th port, including inputs
                                                               nodeId: node.id),
                                  label: POINT4D_W_LABEL,
                                  values: [.number(.zero)]))
        }

        node.outputs = outputs
    }

    // From 3 -> 4 outputs
    // i.e. point3D -> point4D

    // From 2 -> 4 outputs
    // i.e. position/size -> point4D

    // REMOVING INPUTS

    // From 3 -> 2 outputs
    else if usesThreeOutputs(currentNodeType) && usesTwoOutputs(newNodeType) {
        log("unpackNodeTypeChange: remove input")
        // remove an input
        assert(node.sortedOutputs.count == 3)
        let outputs = node.sortedOutputs.dropLast()
        assert(outputs.count == 2)
        node.outputs = NEA(outputs)!
    }

    // From 4 -> 3 outputs:
    else if usesFourOutputs(currentNodeType) && usesThreeOutputs(newNodeType) {
        log("unpackNodeTypeChange: remove input")
        // remove an input
        assert(node.sortedOutputs.count == 4)
        let outputs = node.sortedOutputs.dropLast()
        assert(outputs.count == 3)
        node.outputs = NEA(outputs)!
    }

    // From 4 -> 2 outputs:

    // "newType == size" i.e. size-node was .position type,
    // but now will be made .size(LayerSize) type.
    node = commonNodeTypeChange(node: node,
                                newNodeType: newNodeType,
                                graphTime: graphTime)

    // size-unpack nodes also change their outputs' labels
    node.outputs = updateUnpackNodeLabels(node.sortedOutputs,
                                          newNodeType: newNodeType)

    let labels = node.outputs.map(\.label)
    log("unpackNodeTypeChange: labels: \(labels)")

    return node
}

// Not used ?
func changeSizeUnpackNodeOutputLabels(node: PatchNode,
                                      newNodeType: UserVisibleType) -> PatchNode {
    var node = node

    var output0 = node.sortedOutputs[0]
    var output1 = node.sortedOutputs[1]

    if newNodeType == .size {
        output0.label = "W"
        output1.label = "H"
    } else if newNodeType == .position {
        output0.label = "X"
        output1.label = "Y"
    } else {
        fatalError()
    }

    node.outputs[0] = output0
    node.outputs[1] = output1

    return node
}

let SIZE_WIDTH_LABEL = "W"
let SIZE_HEIGHT_LABEL = "H"
let SIZE_LABELS = [SIZE_WIDTH_LABEL, SIZE_HEIGHT_LABEL]

let POSITION_X_LABEL = "X"
let POSITION_Y_LABEL = "Y"
let POSITION_LABELS = [POSITION_X_LABEL, POSITION_Y_LABEL]

let POINT3D_X_LABEL = POSITION_X_LABEL
let POINT3D_Y_LABEL = POSITION_Y_LABEL
let POINT3D_Z_LABEL = "Z"

let POINT4D_W_LABEL = "W"

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

// TODO: Combine these two fns via a `updateLabel` method on NodeIO

func updatePackNodeLabels(_ inputs: Inputs,
                          newNodeType: UserVisibleType) -> Inputs {
    switch newNodeType {
    case .size:
        return NEA(zip(inputs, SIZE_LABELS).map { input, label in
            input.updateLabel(label)
        })!
    case .position:
        return NEA(zip(inputs, POSITION_LABELS).map { $0.0.updateLabel($0.1) })!
    case .point3D:
        return NEA(zip(inputs, POINT3D_LABELS).map { $0.0.updateLabel($0.1) })!
    case .point4D:
        return NEA(zip(inputs, POINT4D_LABELS).map { $0.0.updateLabel($0.1) })!
    default:
        fatalError()
    }
}

func updateUnpackNodeLabels(_ outputs: Outputs,
                            newNodeType: UserVisibleType) -> Outputs {
    switch newNodeType {
    case .size:
        return NEA(zip(outputs, SIZE_LABELS).map { output, label in
            output.updateLabel(label)
        })!
    case .position:
        return NEA(zip(outputs, POSITION_LABELS).map { $0.0.updateLabel($0.1) })!
    case .point3D:
        return NEA(zip(outputs, POINT3D_LABELS).map { $0.0.updateLabel($0.1) })!
    case .point4D:
        return NEA(zip(outputs, POINT4D_LABELS).map { $0.0.updateLabel($0.1) })!
    default:
        fatalError()
    }
}
