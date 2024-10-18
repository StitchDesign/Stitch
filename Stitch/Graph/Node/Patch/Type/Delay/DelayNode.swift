//
//  DelayNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension DelayStyle: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<DelayStyle> {
        PortValue.delayStyle
    }
}

struct DelayPatchNode: PatchNodeDefinition {
    static let patch = Patch.delay

    static private let _defaultUserVisibleType: UserVisibleType = .number
    static let defaultUserVisibleType: UserVisibleType? = Self._defaultUserVisibleType

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Value",
                    canDirectlyCopyUpstreamValues: true
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "Delay",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.delayStyle(.always)],
                    label: "Style",
                    isTypeStatic: true
                )
            ],
            outputs: [
                .init(
                    label: "Value",
                    type: .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        NodeTimerEphemeralObserver()
    }
}

final class NodeTimerEphemeralObserver: NodeEphemeralObservable {    
    // Buffer of timer objects
    @MainActor var runningTimers: [UUID: DelayNodeTimer] = .init()
    
    // Tracks previous values for delay node to track increasing/decreasing trend.
    // Maps a loop index to a PortValue
    var prevDelayInputValue: PortValue?
}

extension NodeTimerEphemeralObserver {
    @MainActor func onPrototypeRestart() {
        self.runningTimers = .init()
        self.prevDelayInputValue = nil
    }
}

final class DelayNodeTimer {
    private var timer: Timer?

    let timerId: UUID
    let delayValue: Double
    let value: PortValue
    let loopIndex: Int
    let originalNodeType: UserVisibleType?
    weak var ephemeralObserver: NodeTimerEphemeralObserver?
    weak var node: NodeDelegate?

    init(timerId: UUID,
         delayValue: Double,
         value: PortValue,
         loopIndex: Int,
         originalNodeType: UserVisibleType?,
         ephemeralObserver: NodeTimerEphemeralObserver,
         node: NodeDelegate) {
        self.timerId = timerId
        self.delayValue = delayValue
        self.value = value
        self.loopIndex = loopIndex
        self.originalNodeType = originalNodeType
        self.ephemeralObserver = ephemeralObserver
        self.node = node
        self.timer = Timer.scheduledTimer(timeInterval: delayValue,
                                          target: self,
                                          selector: #selector(fireTimer),
                                          userInfo: nil,
                                          repeats: false)
    }

    // Used to create timers for delay node
    @MainActor
    @objc func fireTimer() {
        guard let node = node else {
            return
        }
        
        ephemeralObserver?.assignDelayedValueAction(timerId: timerId,
                                                    node: node,
                                                    value: value,
                                                    loopIndex: loopIndex,
                                                    delayLength: delayValue,
                                                    originalNodeType: originalNodeType)
    }
}

@MainActor
func delayEval(node: PatchNode) -> EvalResult {
    node.loopedEval(NodeTimerEphemeralObserver.self) { values, timerObserver, index in
//        let inputCoordinate = InputCoordinate(portId: 0, nodeId: node.id)
        let prevDelayInputValue = timerObserver.prevDelayInputValue

        guard let inputValue = values.first else {
            return [node.userVisibleType?.defaultPortValue ?? .number(.zero)]
        }
        
        guard let delayValue = values[safe: 1]?.getNumber,
              let style = values[safe: 2]?.delayStyle else {
            return [inputValue.defaultFalseValue]
        }
        
        // If there's no current output (graph just opened or reset),
        // use the default-false-value for this same input kind.
        
        var currentOutput = values[safe: 3] ?? inputValue.defaultFalseValue
        if currentOutput.toNodeType != inputValue.toNodeType {
            currentOutput = inputValue.defaultFalseValue
        }

        let createTimer = {
            let id = UUID()
            let timer = DelayNodeTimer(timerId: id,
                                       delayValue: delayValue,
                                       value: inputValue,
                                       loopIndex: index,
                                       originalNodeType: node.userVisibleType,
                                       ephemeralObserver: timerObserver,
                                       node: node)
            timerObserver.runningTimers.updateValue(timer, forKey: id)
        }

        switch style {
        case .always:
            createTimer()

        // TODO: probably completely broken vs. Origami
        case .increasing:
            // Condition passes if no previous value set
            if inputValue > (prevDelayInputValue ?? PortValue.number(-1 * .infinity)) {
                createTimer()
            } else {
                // Otherwise, update the output right away
                // Update prev value
                timerObserver.prevDelayInputValue = inputValue
                return [inputValue]
            }

        case .decreasing:

            let prev = (prevDelayInputValue ?? PortValue.number(.infinity))

            // Condition passes if no previous value set
            if inputValue <  prev {
                //                log("delayEval: new input less than previous input; will startt timer")
                createTimer()
                // We create the timer, BUT ALSO IMMEDIATELY SEND

            } else {
                // Otherwise, update the output right away
                // Update prev value
                timerObserver.prevDelayInputValue = inputValue
                return [inputValue]
            }
        }

        // Update prev value
        timerObserver.prevDelayInputValue = inputValue

        // Use current outputs for now, the effect will overwrite later
        return [currentOutput]
    }
}
