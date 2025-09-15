//
//  LessThanNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct LessThanPatchNode: PatchNodeDefinition {
    static let patch = Patch.lessThan
    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(200)],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .bool
                )
            ]
        )
    }
}

@MainActor
func lessThanEval(inputs: PortValuesList,
                  outputs: PortValuesList) -> PortValuesList {

    // True just if values in inputs arranged larger -> smaller
    let op: Operation = { (values: PortValues) -> PortValue in
        // All values are expected to be numbers
        
        let numbers: [Double] = values.compactMap(\.getNumber)
        
        // If some inputs were not numbers, we may be dealing with a legacy node
        guard let firstNumber: Double = numbers.first,
              numbers.count == values.count else {
            
            // TODO: Handling legacy case; remove after migration
            if let firstValue = values[safe: 0]?.comparableValue,
               let secondValue = values[safe: 1]?.comparableValue {
                return .bool(firstValue < secondValue)
            } else {
                return .bool(false)
            }
        }
        
        var previousNumber: Double = firstNumber
        // GT node must have
        for number in numbers.dropFirst() {
            // Inputs have to be arranged smaller -> larger
            if number > previousNumber {
                previousNumber = number
                continue
            } else {
                return .bool(false)
            }
        }
        
        return .bool(true)
    }
    
    return resultsMaker(inputs)(op)
}
