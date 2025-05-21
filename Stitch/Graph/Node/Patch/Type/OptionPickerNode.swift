//
//  OptionPickerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let OptionPickerDefaultNodeType = UserVisibleType.number

struct OptionPickerPatchNode: PatchNodeDefinition {
    static let patch = Patch.optionPicker

    static let defaultUserVisibleType: UserVisibleType? = .number
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Option",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: ""
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: ""
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        ComputedNodeState()
    }
}

@MainActor
func optionPickerEval(node: PatchNode) -> EvalResult {

    let inputs = node.inputs
        
    guard let nodeType = node.userVisibleType else {
        fatalErrorIfDebug()
        return EvalResult(outputsValues: [[OptionPickerDefaultNodeType.defaultPortValue]])
    }
    
    let defaultFakeValue: PortValue = nodeType.defaultPortValue
    
    guard let firstInput = inputs.first else {
        fatalErrorIfDebug()
        return .init(outputsValues: [[defaultFakeValue]])
    }
        
    // If selection input has a loop, output will always be a loop
    if firstInput.hasLoop {
        let op: Operation = { (values: PortValues) -> PortValue in
            guard let defaultFakeValue = values.first?.defaultFalseValue else {
                fatalErrorIfDebug()
                return colorDefaultFalse
            }
            
            let selection: Int = Int(values.first?.getNumber ?? 0.0)

                        
            // If selection was negative, grab the first option
            if selection < 0 {
                return values[safe: 1] ?? defaultFakeValue
            }
            
            // If selection is greater than the total options, grab the last option
            else if selection + 1 >= values.count {
                return values.last ?? defaultFakeValue
            } else {
                // + 1 because want to skip the first item in values
                return values[safe: selection + 1] ?? defaultFakeValue
            }
        }
        
        return .init(outputsValues: resultsMaker(inputs)(op))
        
    }
    
    // If selection input is NOT a loop, the output will only be a loop if the selected-option-input contains a loop
    else {
        let selection: Int = Int(firstInput.first?.getNumber ?? 0.0)
        let inputsToPickFrom = PortValuesList(inputs.dropFirst())
        
        let fn = { (newOutput: PortValues?) in
            EvalResult(outputsValues: [newOutput ?? [defaultFakeValue]] )
        }
        
        if selection < 0 {
            return fn(inputsToPickFrom[safe: 0])
        } else if selection >= inputsToPickFrom.count {
            return fn(inputsToPickFrom.last)
        } else {
            // + 1 because want to skip the first item in values
            return fn(inputsToPickFrom[safe: selection])
        }
    }
}
