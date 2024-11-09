//
//  SpringConverterPatches.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/8/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

//struct SpringFromDurationAndBounce { }
//struct SpringFromResponseAndDampingRatio { }
//struct SpringFromSettlingDurationAndDampingRatio { }


// SwiftUI Spring's 1st init
struct SpringFromDurationAndBounceNode: PatchNodeDefinition {
    static let patch = Patch.springFromDurationAndBounce

    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(1)],
                    label: "Duration",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(0.5)],
                    label: "Bounce",
                    isTypeStatic: true
                )
            ],
            outputs: [
                .init(
                    label: "Stiffness",
                    type: .number
                ),
                .init(
                    label: "Damping",
                    type: .number
                )
            ]
        )
    }
}

// SwiftUI Spring's 3rd init
struct SpringFromResponseAndDampingRatioNode: PatchNodeDefinition {
    static let patch = Patch.springFromResponseAndDampingRatio

    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(1)],
                    label: "Response",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(0.5)],
                    label: "Damping Ratio",
                    isTypeStatic: true
                )
            ],
            outputs: [
                .init(
                    label: "Stiffness",
                    type: .number
                ),
                .init(
                    label: "Damping",
                    type: .number
                )
            ]
        )
    }
}


// SwiftUI Spring's 4th init
struct SpringFromSettlingDurationAndDampingRatioNode: PatchNodeDefinition {
    static let patch = Patch.springFromSettlingDurationAndDampingRatio

    static let defaultUserVisibleType: UserVisibleType? = nil

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(1)],
                    label: "Settling Duration",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.number(0.5)],
                    label: "Damping Ratio",
                    isTypeStatic: true
                )
            ],
            outputs: [
                .init(
                    label: "Stiffness",
                    type: .number
                ),
                .init(
                    label: "Damping",
                    type: .number
                )
            ]
        )
    }
}

extension Spring {
    var asSpringConverterOpResult: (PortValue, PortValue) {
        (.number(self.stiffness), .number(self.damping))
    }
}

let defaultSpringConverterOutputs = (PortValue.number(.zero), PortValue.number(.zero))

func springFromDurationAndBounceEval(inputs: PortValuesList,
                                     outputs: PortValuesList) -> PortValuesList {

    let op: Operation2 = { values in
        if let duration = values.first?.getNumber,
           let bounce = values[safe: 1]?.getNumber {
            return Spring.init(duration: duration, bounce: bounce).asSpringConverterOpResult
        } else {
            fatalErrorIfDebug()
            return defaultSpringConverterOutputs
        }
    }
    
    let results = resultsMaker2(inputs)
    return results(op)
}

func springFromResponseAndDampingRatioEval(inputs: PortValuesList,
                                           outputs: PortValuesList) -> PortValuesList {

    let op: Operation2 = { values in
        if let response = values.first?.getNumber,
           let dampingRatio = values[safe: 1]?.getNumber {
            return Spring.init(response: response, dampingRatio: dampingRatio).asSpringConverterOpResult
        } else {
            fatalErrorIfDebug()
            return defaultSpringConverterOutputs
        }
    }
    
    let results = resultsMaker2(inputs)
    return results(op)
}


func springFromSettlingDurationAndDampingRatioEval(inputs: PortValuesList,
                                           outputs: PortValuesList) -> PortValuesList {

    let op: Operation2 = { values in
        if let settlingDuration = values.first?.getNumber,
           let dampingRatio = values[safe: 1]?.getNumber {
            return Spring.init(settlingDuration: settlingDuration, dampingRatio: dampingRatio).asSpringConverterOpResult
        } else {
            fatalErrorIfDebug()
            return defaultSpringConverterOutputs
        }
    }
    
    let results = resultsMaker2(inputs)
    return results(op)
}
