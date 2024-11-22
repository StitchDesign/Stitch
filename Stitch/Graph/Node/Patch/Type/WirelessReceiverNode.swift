//
//  wirelessReceiverNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 11/22/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func wirelessReceiverNode(id: NodeId,
                          n: Double = 0,
                          position: CGSize = .zero,
                          zIndex: Double = 0.0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values: (nil, [.number(n)]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [.number(n)]))

    return PatchNode(
        position: position,
        zIndex: zIndex,
        id: id,
        patchName: .wirelessReceiver,
        inputs: inputs,
        outputs: outputs)
}
