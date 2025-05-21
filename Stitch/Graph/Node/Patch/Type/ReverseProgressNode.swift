//
//  ReversereverseProgressNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/30/22.
//

import Foundation
import StitchSchemaKit

import SwiftUI

struct ReverseProgressNode: PatchNodeDefinition {
    static let patch: Patch = .reverseProgress
    
    static let defaultUserVisibleType: UserVisibleType? = nil
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Value",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "Start",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "End",
                    isTypeStatic: true
                ),
            ],
            outputs: [
                .init(
                    label: "",
                    type: .number
                )
            ]
        )
    }
}

@MainActor
func reverseProgressEval(inputs: PortValuesList, outputs: PortValuesList) -> PortValuesList {
    //    log("reverseProgressEval called")

    let op: Operation = { (values: PortValues) -> PortValue in
        //        log("reverseProgressEval: values: \(values)")
        let n = values[0].getNumber!
        let start = values[1].getNumber!
        let end = values[2].getNumber!

        // ie if n == n2, then just use n
        var reverseProgress: Double = reverseProgress(n, start: start, end: end)

        // TODO: can we find a more principled way of handling this?
        // https://stackoverflow.com/questions/52983262/how-do-i-seperate-negative-zero-from-positive-zero
        // trying to avoid the "-0"
        if reverseProgress == 0 && (reverseProgress.sign == .minus) {
            reverseProgress = 0
        } else if reverseProgress.isNaN {
            reverseProgress = 0
        } else if reverseProgress.isInfinite {
            reverseProgress = 0
        }

        return .number(reverseProgress)
    }

    return resultsMaker(inputs)(op)
}

func reverseProgress(_ n: Double,
                     start: Double = 50,
                     end: Double = 100) -> Double {

    (end - n) / (end - start)
}
