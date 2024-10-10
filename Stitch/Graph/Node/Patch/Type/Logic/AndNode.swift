//
//  AndNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func andNode(id: NodeId,
             n1: Bool = false,
             n2: Bool = false,
             position: CGSize = .zero, zIndex: Double = 0) -> PatchNode {
    let inputs = toInputs(id: id,
                          values: (nil, [.bool(n1)]),
                          (nil, [.bool(n2)]))

    let outputs = toOutputs(id: id,
                            offset: inputs.count,
                            values: (nil, [.bool(n1 && n2)]))

    return PatchNode(position: position,
                     zIndex: zIndex,
                     id: id,
                     patchName: .and,
                     inputs: inputs,
                     outputs: outputs)
}

func andEval(inputs: PortValuesList,
             outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let boolInputs: [Bool] = values.map { $0.getBool ?? false }
        #if DEBUG
        if boolInputs.isEmpty {
            fatalError("andEval")
        }
        #endif
        let opResult = boolInputs.allSatisfy(identity)
        return .bool(opResult)
    }

    return resultsMaker(inputs)(op)
}
