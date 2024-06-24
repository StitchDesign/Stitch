//
//  NotNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/29/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func notNode(id: NodeId,
             n1: Bool = false,
             position: CGSize = .zero,
             zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(id: id,
                          values: (nil, [.bool(n1)]))

    let outputs = toOutputs(id: id,
                            offset: inputs.count,
                            values: (nil, [.bool(!n1)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .not,
        inputs: inputs,
        outputs: outputs)
}

func notEval(inputs: PortValuesList,
             outputs: PortValuesList) -> PortValuesList {

    let op: Operation = { (values: PortValues) -> PortValue in
        if let a = values.first!.getBool {
            return .bool(!a)
        } else {
            fatalError("orEval")
        }
    }

    return resultsMaker(inputs)(op)
}
