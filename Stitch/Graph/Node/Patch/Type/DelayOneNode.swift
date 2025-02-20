//
//  DelayOneNode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/31/24.
//

import Foundation

struct DelayOneNode: PatchNodeDefinition {
    static let patch = Patch.delayOne
    
    static let defaultUserVisibleType: UserVisibleType = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(defaultType: .number,
                     canDirectlyCopyUpstreamValues: true)
            ],
            outputs: [
                .init(
                    type: .number
                )
            ]
        )
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        DelayOneEvalObserver()
    }
    
    @MainActor
    static func eval(node: NodeViewModel) -> EvalResult {
        node.loopedEval(DelayOneEvalObserver.self) { values, observer, _ in
            guard let value = values.first else {
                return .init(outputs: [DelayOneNode.defaultUserVisibleType.defaultPortValue], willRunAgain: true)
            }
            
            let output = observer.nextOutput

            // Set input as return value for next frame
            observer.nextOutput = value
            
            // Mark node as needing to be calcuated for next frame if values changed
            let shouldRunOnNextFrame = output != value
            return .init(outputs: [output], willRunAgain: shouldRunOnNextFrame)
        }
        .toImpureEvalResult()
    }
    
    static let description = """
Delays the incoming value by one frame. Note that Stitch runs between 60-120 FPS depending on your device.

*Inputs*
• The value to delay

*Outputs*
• The delayed value
"""
}

final class DelayOneEvalObserver: NodeEphemeralObservable {
    var nextOutput = DelayOneNode.defaultUserVisibleType.defaultPortValue
}

extension DelayOneEvalObserver {
    func onPrototypeRestart() {
        self.nextOutput = DelayOneNode.defaultUserVisibleType.defaultPortValue
    }
}
