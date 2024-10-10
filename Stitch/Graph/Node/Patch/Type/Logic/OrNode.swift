//
//  OrNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func orNode(id: NodeId,
            n1: Bool = false,
            n2: Bool = false,
            position: CGSize = .zero,
            zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(id: id,
                          values: (nil, [.bool(n1)]),
                          (nil, [.bool(n2)]))

    let outputs = toOutputs(id: id,
                            offset: inputs.count,
                            values: (nil, [.bool(n1 || n2)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .or,
        inputs: inputs,
        outputs: outputs)
}

func orEval(inputs: PortValuesList,
            outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        let boolInputs = values.compactMap(\.getBool)
        #if DEBUG
        if boolInputs.isEmpty {
            fatalError("orEval")
        }
        #endif
        // If at least one input-value is true (i.e. satisfies identity predicate), then the output of this node will be true.
        let opResult = !boolInputs.filter(identity).isEmpty
        return .bool(opResult)
    }

    return resultsMaker(inputs)(op)
}
