//
//  ModNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/25/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func modNode(id: NodeId,
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
    
    let initialModValue = mod(n1, n2)
    
    let outputs = toOutputs(id: id,
                           offset: inputs.count,
                           values: (nil, [.number(initialModValue)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .mod,
        userVisibleType: .number,
        inputs: inputs,
        outputs: outputs)
}


@MainActor
func modEval(inputs: PortValuesList,
             evalKind: MathNodeTypeWithColor) -> PortValuesList {
    
    let result = resultsMaker(inputs)
    
    switch evalKind {
    case .number:
        return result(ModEvalOps.numberOperation)
    case .size:
        return result(ModEvalOps.sizeOperation)
    case .position:
        return result(ModEvalOps.positionOperation)
    case .point3D:
        return result(ModEvalOps.point3DOperation)
    case .color:
        return result(ModEvalOps.colorOperation)
    }
}

struct ModEvalOps {
    
    @MainActor
    static let numberOperation: Operation = { (values: PortValues) -> PortValue in
        let n = values[0].getNumber ?? .zero
        let n2 = values[1].getNumber ?? .zero
        return .number(mod(n, n2))
    }
    
    @MainActor
    static let positionOperation: Operation = { (values: PortValues) -> PortValue in
        let positions = values.compactMap { $0.getPosition }
        guard positions.count >= 2 else { return .position(.zero) }
        
        let pos1 = positions[0]
        let pos2 = positions[1]
        return .position(CGPoint(x: mod(pos1.x, pos2.x),
                               y: mod(pos1.y, pos2.y)))
    }
    
    @MainActor
    static let sizeOperation: Operation = { (values: PortValues) -> PortValue in
        let sizes = values.compactMap { $0.getSize?.asAlgebraicCGSize }
        guard sizes.count >= 2 else { return .size(.zero) }
        
        let size1 = sizes[0]
        let size2 = sizes[1]
        return .size(CGSize(width: mod(size1.width, size2.width),
                          height: mod(size1.height, size2.height)).toLayerSize)
    }
    
    @MainActor
    static let point3DOperation: Operation = { (values: PortValues) -> PortValue in
        let points = values.compactMap { $0.getPoint3D }
        guard points.count >= 2 else { return .point3D(.zero) }
        
        let point1 = points[0]
        let point2 = points[1]
        return .point3D(Point3D(x: mod(point1.x, point2.x),
                               y: mod(point1.y, point2.y),
                               z: mod(point1.z, point2.z)))
    }
    
    @MainActor
    static let colorOperation: Operation = { (values: PortValues) -> PortValue in
        let colors = values.compactMap { $0.getColor }
        guard colors.count >= 2 else { return .color(.clear) }
        
        let color1 = colors[0].asRGBA
        let color2 = colors[1].asRGBA
        
        let newRGBA = RGBA(
            red: mod(color1.red, color2.red),
            green: mod(color1.green, color2.green),
            blue: mod(color1.blue, color2.blue),
            alpha: mod(color1.alpha, color2.alpha))
        return .color(.init(rgba: newRGBA))
    }
}

func mod(_ n: Double, _ n2: Double) -> Double {
    n2 == 0
        ? 0
        : n.truncatingRemainder(dividingBy: n2).rounded(toPlaces: 3)
}
