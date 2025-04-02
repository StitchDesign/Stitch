//
//  DivideNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func dividePatchNode(id: NodeId,
                     n1: Double = 0,
                     n2: Double = 0,
                     position: CGPoint = .zero,
                     zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.number(n1)]),
        (nil, [.number(n2)]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [.number(zeroCompatibleDivision(numerator: n1, denominator: n2))]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .divide,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

func zeroCompatibleDivision(numerator: Double, denominator: Double) -> Double {
    if denominator == 0 {
        // If we attempt to divide by 0, default to 0.
        return numerator * denominator
    } else {
        return numerator / denominator
    }
}

@MainActor
func divideEval(inputs: PortValuesList,
                evalKind: MathNodeTypeWithColor) -> PortValuesList {

    let numberOperation: Operation = { (values: PortValues) -> PortValue in

        guard let head: Double = values.first?.getNumber else {
            return defaultNumber
        }
        let tail: PortValues = Array(values.dropFirst())

        // unlike addition and multiplication,
        // can't start with the identity element as the numerator.
        return .number(tail.reduce(head) { (acc: Double, value: PortValue) -> Double in

            zeroCompatibleDivision(
                numerator: acc,
                denominator: (value.getNumber ?? .multiplicationIdentity))
        })
    }

    let positionOperation: Operation = { (values: PortValues) -> PortValue in

        let head = values.first?.getPosition ?? .zero
        let tail: PortValues = Array(values.dropFirst())

        return .position(tail.reduce(head) { (acc: CGPoint, value: PortValue) -> CGPoint in
            if let x = value.getPosition {
                return CGPoint(
                    x: zeroCompatibleDivision(
                        numerator: Double(acc.x),
                        denominator: Double(x.x)),
                    y: zeroCompatibleDivision(
                        numerator: Double(acc.y),
                        denominator: Double(x.y)))
            } else {
                fatalError("divideEval: position")
            }
        })
    }

    let sizeOperation: Operation = { (values: PortValues) -> PortValue in

        let sizes: [CGSize] = values.map { $0.getSize?.asAlgebraicCGSize ?? .zero }
        let head: CGSize = sizes.first ?? .zero

        let reduced = sizes.dropFirst().reduce(head) { (acc: CGSize, value: CGSize) -> CGSize in
            CGSize(
                width: zeroCompatibleDivision(numerator: Double(acc.width),
                                              denominator: Double(value.width)),
                height: zeroCompatibleDivision(numerator: Double(acc.height),
                                               denominator: Double(value.height)))
        }
        return .size(reduced.toLayerSize)
    }

    let point3DOperation: Operation = { (values: PortValues) -> PortValue in

        let head: Point3D = values.first?.getPoint3D ?? .zero
        let tail: PortValues = Array(values.dropFirst())

        return .point3D(tail.reduce(head) { (acc: Point3D, value: PortValue) -> Point3D in
            if let x = value.getPoint3D {
                return Point3D(
                    x: zeroCompatibleDivision(numerator: acc.x, denominator: x.x),
                    y: zeroCompatibleDivision(numerator: acc.y, denominator: x.y),
                    z: zeroCompatibleDivision(numerator: acc.z, denominator: x.z))
            } else {
                fatalError("divideEval: point3DOperation")
            }
        })
    }

    let colorOperation: Operation = { (values: PortValues) -> PortValue in
        guard let firstColor = values.first?.getColor else {
            return .color(.clear)
        }
        
        let tail = values.tail
        
        let result = tail.reduce(firstColor) { (acc: Color, value: PortValue) -> Color in
            guard let colorToDivide = value.getColor else { return acc }
            
            let accRGBA = acc.asRGBA
            let divideRGBA = colorToDivide.asRGBA
            
            let newRGBA = RGBA(
                red: zeroCompatibleDivision(numerator: accRGBA.red, denominator: divideRGBA.red),
                green: zeroCompatibleDivision(numerator: accRGBA.green, denominator: divideRGBA.green),
                blue: zeroCompatibleDivision(numerator: accRGBA.blue, denominator: divideRGBA.blue),
                alpha: zeroCompatibleDivision(numerator: accRGBA.alpha, denominator: divideRGBA.alpha)
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
