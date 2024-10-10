//
//  ModNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/25/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ModNode: PatchNodeDefinition {
    static let patch: Patch = .mod
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(defaultValues: [.number(1)], label: ""),
                .init(defaultValues: [.number(0)], label: "")
            ],
            outputs: [.init(label: "",
                            type: .number)])
    }
}

// TODO: update to support position, size etc.?
func modEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {
    let op: Operation = { (values: PortValues) -> PortValue in
        //        log("modEval: values: \(values)")
        let n = values[0].getNumber ?? .zero
        let n2 = values[1].getNumber ?? .zero

        // ie if n == n2, then just use n
        let mod: Double = mod(n, n2)

        return .number(mod)
    }

    return resultsMaker(inputs)(op)
}

func mod(_ n: Double, _ n2: Double) -> Double {
    n2 == 0
        ? 0
        : n.truncatingRemainder(dividingBy: n2).rounded(toPlaces: 3)
}
