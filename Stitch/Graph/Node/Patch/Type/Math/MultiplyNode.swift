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

// node 502D3E
//@MainActor
//func multiplyEval(inputs: PortValuesList,
//                  evalKind: MathNodeTypeWithColor) -> PortValuesList {
//

@MainActor
func multiplyEval(node: PatchNode,
                  graph: GraphState) -> EvalResult {
    let inputs: PortValuesList = node.inputs

    
//    // alternatively, try CRASHING here if we have number eval kind but first input is not a number
//    if let n = inputs.first?.first?.getNumber,
//       n == 1 {
//        log("multiplyEval: had 1 in first input")
//    }
    
    let numberOperation: Operation = { (values: PortValues) -> PortValue in
        .number(values.reduce(.multiplicationIdentity) { (acc: Double, value: PortValue) -> Double in
            if let n = value.getNumber {
                return acc * n
            } else {
                log("multiplyEval: did not have number in value \(value)")
                return acc * .multiplicationIdentity
            }
            
//            acc * (value.getNumber ?? .multiplicationIdentity)
        })
    }

    if node.id.uuidString.contains("502D3EBA") {
        log("multiplyEval: for node \(node.id)")
        log("multiplyEval: graphTime \(graph.graphStepState.graphTime)")
        log("multiplyEval: inputs: \(inputs)")
        let k = resultsMaker(inputs)(numberOperation)
        log("multiplyEval: result: \(k)")
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

//    switch evalKind {
    switch node.userVisibleType! {
    case .number:
        return .init(outputsValues: result(numberOperation))
    case .position:
        return .init(outputsValues: result(positionOperation))
    case .size:
        return .init(outputsValues: result(sizeOperation))
    case .point3D:
        return .init(outputsValues: result(point3DOperation))
    case .color:
        return .init(outputsValues: result(colorOperation))
    default:
        fatalError()
    }
}
