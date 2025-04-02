//
//  LessThanOrEqualNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/7/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

@MainActor
func lessThanOrEqualPatchNode(id: NodeId,
                              n: Double = 200,
                              position: CGPoint = .zero,
                              zIndex: Double = 0) -> PatchNode {

    let inputs = toInputs(
        id: id,
        values:
            (nil, [.number(0)]),
        (nil, [.number(n)]))

    let outputs = toOutputs(
        id: id,
        offset: inputs.count,
        values: (nil, [.bool(0 <= n)]))

    return PatchNode(position: position,
                     zIndex: zIndex,
                     id: id,
                     patchName: .lessThanOrEqual,
                     inputs: inputs,
                     outputs: outputs)
}

@MainActor
func lessThanOrEqualEval(inputs: PortValuesList,
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
                return .bool(firstValue <= secondValue)
            } else {
                return .bool(false)
            }
        }
        
        var previousNumber: Double = firstNumber
        // GT node must have
        for number in numbers.dropFirst() {
            // Inputs have to be arranged smaller -> larger
            if number >= previousNumber {
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
