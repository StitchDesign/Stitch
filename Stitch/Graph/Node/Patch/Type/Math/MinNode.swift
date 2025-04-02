//
//  MinNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit

@MainActor
func minNode(id: NodeId,
             n1: Double = 1.0,
             n2: Double = 0.0,
             position: CGPoint = .zero,
             zIndex: Double = 0,
             n1Loop: PortValues? = nil,
             n2Loop: PortValues? = nil) -> PatchNode {

    let inputs = toInputs(id: id,
                         values:
                           (nil, n1Loop ?? [.number(n1)]),
                           (nil, n2Loop ?? [.number(n2)]))
    
    // Calculate initial output using the same logic as MinEvalOps.numberOperation
    let initialValues: [PortValue] = [.number(n1), .number(n2)]
    let minValue = initialValues.compactMap { $0.getNumber }.min() ?? .zero
    
    let outputs = toOutputs(id: id,
                           offset: inputs.count,
                           values: (nil, [.number(minValue)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .min,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}

@MainActor
func minEval(inputs: PortValuesList,
             evalKind: ArithmeticNodeType) -> PortValuesList {
    
    // Get input values for evaluation
    let values = inputs.flatMap { $0 }
    let result = resultsMaker(inputs)
    
    // Check if any input is a string
    let hasStringInput = values.contains { portValue in
        if case .string(_) = portValue { return true }
        return false
    }
    
    if hasStringInput {
        return result(MinEvalOps.stringOperation)
    }
    
    switch evalKind {
    case .number:
        return result(MinEvalOps.numberOperation)
    case .size:
        return result(MinEvalOps.sizeOperation)
    case .position:
        return result(MinEvalOps.positionOperation)
    case .point3D:
        return result(MinEvalOps.point3DOperation)
    case .color:
        return result(MinEvalOps.colorOperation)
    }
}

struct MinEvalOps {
    
    @MainActor static let numberOperation: Operation = { (values: PortValues) -> PortValue in
        .number(values.compactMap { $0.getNumber }.min() ?? .zero)
    }
    
    static let stringOperation: Operation = { (values: PortValues) -> PortValue in
        let strings = values.compactMap { $0.getString }
        let minString = strings.min { $0.string.count < $1.string.count } ?? .additionIdentity
        return .string(minString)
    }
    
    static let positionOperation: Operation = { (values: PortValues) -> PortValue in
        let positions = values.compactMap { $0.getPosition }
        guard !positions.isEmpty else { return .position(.zero) }
        
        let minPosition = positions.min { pos1, pos2 in
            let dist1 = sqrt(pos1.x * pos1.x + pos1.y * pos1.y)
            let dist2 = sqrt(pos2.x * pos2.x + pos2.y * pos2.y)
            return dist1 < dist2
        } ?? .zero
        return .position(minPosition)
    }
    
    static let sizeOperation: Operation = { (values: PortValues) -> PortValue in
        let sizes = values.compactMap { $0.getSize?.asAlgebraicCGSize }
        guard !sizes.isEmpty else { return .size(.zero) }
        
        let minSize = sizes.min { size1, size2 in
            (size1.width * size1.height) < (size2.width * size2.height)
        } ?? .zero
        return .size(minSize.toLayerSize)
    }
    
    static let point3DOperation: Operation = { (values: PortValues) -> PortValue in
        let points = values.compactMap { $0.getPoint3D }
        guard !points.isEmpty else { return .point3D(.zero) }
        
        let minPoint = points.min { point1, point2 in
            let dist1 = sqrt(point1.x * point1.x + point1.y * point1.y + point1.z * point1.z)
            let dist2 = sqrt(point2.x * point2.x + point2.y * point2.y + point2.z * point2.z)
            return dist1 < dist2
        } ?? .zero
        return .point3D(minPoint)
    }
    
    static let colorOperation: Operation = { (values: PortValues) -> PortValue in
        let colors = values.compactMap { $0.getColor }
        guard !colors.isEmpty else { return .color(.clear) }
        
        let minColor = colors.min { color1, color2 in
            let rgba1 = color1.asRGBA
            let rgba2 = color2.asRGBA
            
            let length1 = sqrt(rgba1.red * rgba1.red + rgba1.green * rgba1.green + rgba1.blue * rgba1.blue) / sqrt(3.0)
            let length2 = sqrt(rgba2.red * rgba2.red + rgba2.green * rgba2.green + rgba2.blue * rgba2.blue) / sqrt(3.0)
            
            return length1 < length2
        } ?? .clear
        return .color(minColor)
    }
}
