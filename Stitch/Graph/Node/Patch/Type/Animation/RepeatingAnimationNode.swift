//
//  RepeatingAnimationNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/18/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct RepeatingAnimationNode: PatchNodeDefinition {
    static let patch = Patch.repeatingAnimation
    
    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.bool(true)],
                    label: "Enabled"
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "Duration"
                ),
                .init(
                    defaultValues: [.animationCurve(.linear)],
                    label: "Curve"
                ),
                .init(
                    defaultValues: [.bool(false)],
                    label: "Mirrored"
                ),
                .init(
                    defaultValues: [.pulse(0)],
                    label: "Reset"
                )
            ],
            outputs: [
                .init(
                    label: "Progress",
                    type: .number
                )
            ]
        )
    }
    
    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        // Note: RepeatingAnimation node uses a number type classic animation state, but does not support node-type-changing.
        // Cross-reference nodes with `Patch.availableNodeTypes` to know if a node supports node-type-changing.
        let state: ClassicAnimationState = ClassicAnimationState.defaultFromNodeType(.number)
        return ComputedNodeState(classicAnimationState: state)
    }
}

@MainActor
func repeatingAnimationEval(node: PatchNode,
                            graphStep: GraphStepState) -> ImpureEvalResult {
    node.loopedEval(ComputedNodeState.self) { values, computedState, loopIndex in
        return repeatingAnimationEvalOpNumber(
            values: values,
            computedState: computedState,
            graphTime: graphStep.graphTime,
            graphFrameCount: graphStep.graphFrameCount,
            fps: graphStep.estimatedFPS)
    }//defaultOutputs: [[defaultNumber]])
}

func repeatingAnimationEvalOpNumber(values: PortValues,
                                    computedState: ComputedNodeState,
                                    graphTime: TimeInterval,
                                    graphFrameCount: Int,
                                    fps: StitchFPS) -> ImpureEvalOpResult {

    // Our current output is always the 'starting point'
    // of a given animation step.
    let currentOutput = values[safe: 5]?.getNumber ?? .zero
    
    let defaultResult = ImpureEvalOpResult(
        outputs: [.number(currentOutput)],
        willRunAgain: false
    )
    
    guard let enabled = values[safe: 0]?.getBool,
          let duration = values[safe: 1]?.getNumber,
          let curve = values[safe: 2]?.getAnimationCurve,
          let mirrored = values[safe: 3]?.getBool,
            // the last time we pulsed
          let reset: TimeInterval = values[safe: 4]?.getPulse,
          !duration.isZero && enabled else {
        // log("repeatingAnimationEvalOpNumber: default result")
        return defaultResult
    }

    var animationState = computedState.classicAnimationState?.asSingleState ?? .init()
    
    let atProgressEnd = currentOutput >= 1
    let atProgressStart = currentOutput <= 0
    
    // TODO: add manual pulse option
    let receivedPulse: Bool = reset == graphTime

    //    log("repeatingAnimationEvalOpNumber: enabled: \(enabled)")
    //    log("repeatingAnimationEvalOpNumber: duration: \(duration)")
    //    log("repeatingAnimationEvalOpNumber: curve: \(curve)")
    //    log("repeatingAnimationEvalOpNumber: mirrored: \(mirrored)")
    //    log("repeatingAnimationEvalOpNumber: reset: \(reset)")
    //    log("repeatingAnimationEvalOpNumber: currentOutput: \(currentOutput)")
    //    log("repeatingAnimationEvalOpNumber: atProgressEnd: \(atProgressEnd)")
    //    log("repeatingAnimationEvalOpNumber: atProgressStart: \(atProgressStart)")
    //    log("repeatingAnimationEvalOpNumber: graphTime: \(graphTime)")
    //    log("repeatingAnimationEvalOpNumber: receivedPulse: \(receivedPulse)")

    if receivedPulse {
        //        #if DEV_DEBUG
        //        log("reset per receivedPulse")
        //        #endif
        
        let newStart: Double = 0
        let newGoal: Double = 1
        
        animationState.frameCount = 0 //
        animationState.initialValues = InitialAnimationValue(
            start: newStart,
            goal: newGoal)
    }
    
    // ORIGINAL: had reversed these
    // REFACTOR: changed them, but then we don't even run
    
    // i.e. we're currently at 1
    //    if atProgressEnd {
    else if atProgressEnd {
        //        #if DEV_DEBUG
        //        log("reset per atProgressEnd")
        //        #endif
        
        // mirrored: start at 1, move toward 0
        // non-mirrored: start back at 0, move toward 1
        let newStart: Double = mirrored ? 1 : 0
        let newGoal: Double = mirrored ? 0 : 1
        
        // reset the animation state
        animationState.frameCount = 0 //
        animationState.initialValues = InitialAnimationValue(
            start: newStart,
            goal: newGoal)
    }
    
    // ie we're currently at 0
    else if atProgressStart {
        //        #if DEV_DEBUG
        //        log("reset per atProgressStart")
        //        #endif
        
        // not affected by mirroring
        let newStart: Double = 0
        let newGoal: Double = 1
        
        animationState.frameCount = 0 //
        animationState.initialValues = InitialAnimationValue(
            start: newStart,
            goal: newGoal)
    }

    // Increment frameCount
    animationState.frameCount += 1
    
    guard let initialValues = animationState.initialValues else {
        return defaultResult
    }
    let (newValue, _) = runAnimation(
        toValue: initialValues.goal,
        duration: duration,
        difference: initialValues.difference,
        startValue: initialValues.start,
        // curve: values[2].getAnimationCurve!,
        curve: curve,
        currentFrameCount: animationState.frameCount,
        fps: fps)
    
    computedState.classicAnimationState = .oneField(animationState)
    return .init(
        outputs: [.number(newValue)],
        willRunAgain: true // always true ?
    )
}
