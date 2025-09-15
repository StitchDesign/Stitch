//
//  ClipNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/20/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit


struct ClipPatchNode: PatchNodeDefinition {
    static let patch = Patch.clip

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Value"
                ),
                .init(
                    defaultValues: [.number(-5)],
                    label: "Min"
                ),
                .init(
                    defaultValues: [.number(5)],
                    label: "Max"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .number
                )
            ]
        )
    }
}

@MainActor
func clipEval(inputs: PortValuesList,
              outputs: PortValuesList) -> PortValuesList {
    
    let op: Operation = { (values: PortValues) -> PortValue in
        if let value = values.first?.getNumber,
           let min = values[1].getNumber,
           let max = values[2].getNumber {
            return .number(getNumberBetween(value: value, min: min, max: max))
        } else {
            fatalErrorIfDebug()
            return .number(.zero)
        }
    }

    return resultsMaker(inputs)(op)
}


func getNumberBetween(value: Double,
                      min: Double,
                      max: Double) -> Double {
    if value >= max {
        return max
    } else if value <= min {
        return min
    } else {
        return value
    }
}


// i.e. clip
func getNumberBetween(value: Int,
                      min: Int,
                      max: Int) -> Int {
    if value >= max {
        return max
    } else if value <= min {
        return min
    } else {
        return value
    }
}
