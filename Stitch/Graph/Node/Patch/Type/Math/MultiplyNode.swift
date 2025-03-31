//
//  MultiplyNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func multiplyPatchNode(id: NodeId,
                       n1: Double = 0,
                       n2: Double = 0,
                       position: CGSize = .zero, zIndex: Double = 0) -> PatchNode {
    let inputs = toInputs(id: id,
                          values: (nil, [.number(n1)]),
                          (nil, [.number(n2)]))

    let outputs = toOutputs(id: id,
                            offset: inputs.count,
                            values: (nil, [.number(n1 * n2)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .multiply,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func multiplyEval(inputs: PortValuesList,
                  evalKind: MathNodeTypeWithColor) -> PortValuesList {

    let numberOperation: Operation = { (values: PortValues) -> PortValue in
        .number(values.reduce(.multiplicationIdentity) { (acc: Double, value: PortValue) -> Double in
            acc * (value.getNumber ?? .multiplicationIdentity)
        })
    }
    
    let positionOperation: Operation = { (values: PortValues) -> PortValue in
        .position(values.reduce(.multiplicationIdentity) { (acc: CGPoint, value: PortValue) -> CGPoint in
            acc * (value.getPosition ?? .multiplicationIdentity)
        })
    }

    let sizeOperation: Operation = { (values: PortValues) -> PortValue in

        let sizes: [CGSize] = values.map { $0.getSize!.asAlgebraicCGSize }

        let reduced = sizes.reduce(.multiplicationIdentity) { (acc: CGSize, value: CGSize) -> CGSize in
            acc * value
        }
        return .size(reduced.toLayerSize)
    }

    let point3DOperation: Operation = { (values: PortValues) -> PortValue in
        .point3D(values.reduce(.multiplicationIdentity) { (acc: Point3D, value: PortValue) -> Point3D in
            acc * (value.getPoint3D ?? .multiplicationIdentity)
        })
    }

    let colorOperation: Operation = { (values: PortValues) -> PortValue in
        let colors = values.compactMap { $0.getColor }
        guard !colors.isEmpty else { return .color(.clear) }
        
        let result = colors.reduce(Color.white) { (acc: Color, color: Color) -> Color in
            let accRGBA = acc.asRGBA
            let colorRGBA = color.asRGBA
            
            let newRGBA = RGBA(
                red: accRGBA.red * colorRGBA.red,
                green: accRGBA.green * colorRGBA.green,
                blue: accRGBA.blue * colorRGBA.blue,
                alpha: accRGBA.alpha * colorRGBA.alpha
            )
            
            return newRGBA.toColor
        }
        
        return .color(result)
    }

    let result = resultsMaker(inputs)

    switch evalKind {
    case .number:
        return result(numberOperation)
    case .position:
        return result(positionOperation)
    case .size:
        return result(sizeOperation)
    case .point3D:
        return result(point3DOperation)
    case .color:
        return result(colorOperation)
    }
}
