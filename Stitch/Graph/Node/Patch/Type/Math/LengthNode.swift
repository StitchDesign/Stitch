//
//  LengthNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func lengthNode(id: NodeId,
                n: Double = 1,
                position: CGPoint = .zero,
                zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.number(n)])
    )

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values:
            (nil, [.number(abs(n))])
    )

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .length,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func lengthEval(inputs: PortValuesList,
                evalKind: ArithmeticNodeType) -> PortValuesList {
    // log("lengthEval called")

    
    // Check if any input is a string
    let hasStringInput = inputs.contains { portValues in
        portValues.contains { portValue in
            if case .string(_) = portValue {
                return true
            }
            return false
        }
    }
    
    
    
    let stringOp: Operation = { (values: PortValues) -> PortValue in
        let str = values[safe: 0]?.getString?.string ?? ""
        let length = str.count
        return .number(Double(length))
    }

    let sizeOp: Operation = { (values: PortValues) -> PortValue in
        // log("lengthEval: values: \(values)")
        let n = values[safe: 0]?.getSize?.asAlgebraicCGSize ?? .additionIdentity
        let length: Double = hypot(n.width, n.height)
        return .number(length)
    }

    let positionOp: Operation = { (values: PortValues) -> PortValue in
        // log("lengthEval: values: \(values)")
        let n = values[safe: 0]?.getPosition ?? .additionIdentity
        let length: Double = hypot(n.x, n.y)
        return .number(length)
    }

    let point3DOp: Operation = { (values: PortValues) -> PortValue in
        // log("lengthEval: values: \(values)")
        let n = values[safe: 0]?.getPoint3D ?? .additionIdentity
        let length: Double = hypot(n.x, n.y)
        return .number(length)
    }

    let numberOp: Operation = { (values: PortValues) -> PortValue in
        let n = values[safe: 0]?.getNumber ?? .additionIdentity // Use a default value if nil
        // Format to remove decimal point and count digits
        let length = String(format: "%.0f", abs(n)).count
        return .number(Double(length)) // Return the length as a number
    }

    let colorOp: Operation = { (values: PortValues) -> PortValue in
        guard let color = values[safe: 0]?.getColor else { return .number(0) } // Default to 0 for no color
        let rgba = color.asRGBA
        
        // Calculate normalized vector length in RGB space
        let length = sqrt(
            rgba.red * rgba.red +
            rgba.green * rgba.green +
            rgba.blue * rgba.blue
        ) / sqrt(3.0) // Normalize by dividing by √3 so white has length 1
        
        return .number(length)
    }

    let result = resultsMaker(inputs)
        
    if hasStringInput {
        return result(stringOp)
    }

    switch evalKind {
    case .number:
        return result(numberOp)
    case .position:
        return result(positionOp)
    case .size:
        return result(sizeOp)
    case .point3D:
        return result(point3DOp)
    case .color:
        return result(colorOp)
    }
}
