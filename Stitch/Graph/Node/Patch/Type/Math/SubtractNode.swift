//
//  SubtractNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI

@MainActor
func subtractNode(id: NodeId,
                  n1: Double = 0.0,
                  n2: Double = 0.0,
                  position: CGPoint = .zero,
                  zIndex: Double = 0,
                  n1Loop: PortValues? = nil,
                  n2Loop: PortValues? = nil) -> PatchNode {


    let inputs = toInputs(id: id,
                            values:
                              (nil, n1Loop ?? [.number(n1)]),
                            (nil, n2Loop ?? [.number(n2)]))

    let outputs = toOutputs(id: id, offset: inputs.count,
                              values: (nil, [.number(n1 + n2)]))
    
    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .subtract,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func subtractEval(inputs: PortValuesList,
                  evalKind: MathNodeTypeWithColor) -> PortValuesList {

    let numberOperation: Operation = { (values: PortValues) -> PortValue in

        guard let head: Double = values.first?.getNumber else {
            return defaultNumber
        }
        let tail: PortValues = values.tail

        return .number(tail.reduce(head) { (acc: Double, value: PortValue) -> Double in
            acc - (value.getNumber ?? .additionIdentity)
        })
    }

    let positionOperation: Operation = { (values: PortValues) -> PortValue in

        guard let head = values.first?.getPosition else {
            return defaultPositionFalse
        }
        let tail: PortValues = values.tail

        return .position(tail.reduce(head) { (acc: CGPoint, value: PortValue) -> CGPoint in
            acc - (value.getPosition ?? .additionIdentity)
        })
    }

    let sizeOperation: Operation = { (values: PortValues) -> PortValue in

        let sizes: [CGSize] = values.map { $0.getSize?.asAlgebraicCGSize ?? .additionIdentity }

        let head = sizes.first!
        let tail = sizes.tail

        let reduced = tail.reduce(head) { (acc: CGSize, value: CGSize) -> CGSize in
            acc - value
        }
        return .size(reduced.toLayerSize)
    }

    let point3DOperation: Operation = { (values: PortValues) -> PortValue in

        let head = values.first?.getPoint3D ?? .zero
        let tail = values.tail

        return .point3D(tail.reduce(head) { (acc: Point3D, value: PortValue) -> Point3D in
            acc - (value.getPoint3D ?? .additionIdentity)
        })
    }

    let colorOperation: Operation = { (values: PortValues) -> PortValue in
        guard let firstColor = values.first?.getColor else {
            return .color(.clear)
        }
        
        let tail = values.tail
        
        let result = tail.reduce(firstColor) { (acc: Color, value: PortValue) -> Color in
            guard let colorToSubtract = value.getColor else { return acc }
            
            let accRGBA = acc.asRGBA
            let subtractRGBA = colorToSubtract.asRGBA
            
            let newRGBA = RGBA(
                red: max(0, accRGBA.red - subtractRGBA.red),
                green: max(0, accRGBA.green - subtractRGBA.green),
                blue: max(0, accRGBA.blue - subtractRGBA.blue),
                alpha: max(0, accRGBA.alpha - subtractRGBA.alpha)
            )
            
            return newRGBA.toColor
        }
        
        return .color(result)
    }

    let result = resultsMaker(inputs)

    switch evalKind {
    case .number:
        return result(numberOperation)
    case .size:
        return result(sizeOperation)
    case .position:
        return result(positionOperation)
    case .point3D:
        return result(point3DOperation)
    case .color:
        return result(colorOperation)
    }
}
