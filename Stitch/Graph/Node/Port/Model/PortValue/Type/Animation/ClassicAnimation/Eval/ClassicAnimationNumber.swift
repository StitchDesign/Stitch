//
//  ClassicAnimationNumber.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/11/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension ClassicAnimationState {
    var asSingleState: OneFieldAnimationProgress {
        switch self {
        case .oneField(let x):
            return x
        default:
            #if DEV || DEV_DEBUG
            log("asSingleState: returning default state")
            #endif
            return .init()
        }
    }
}

extension TimeInterval {
    // i.e. Graph was just opened or reset
    var graphJustStarted: Bool {
        self == .zero
    }
}

func classicAnimationEvalOpNumber(values: PortValues,
                                  computedState: ComputedNodeState,
                                  graphTime: TimeInterval,
                                  graphFrameCount: Int,
                                  fps: StitchFPS) -> ImpureEvalOpResult {

     // log("classicAnimationEvalOpNumber: values: \(values)")
     // log("classicAnimationEvalOpNumber: computedState: \(computedState)")
    
    // Doesn't change during animation itself;
    // ie if we change this, then a NEW animation starts.
    let toValue: Double = values.first?.getNumber ?? .zero
     // log("classicAnimationEvalOpNumber: toValue: \(toValue)")

    // Our current output is always the 'starting point'
    // of a given animation step.
    let currentOutput: Double = graphTime.graphJustStarted ? toValue : values.last?.getNumber ?? toValue
    
    let duration: Double = values[safe: 1]?.getNumber ?? .zero
       
    // When duration is 0, we immediately jump to the toValue
    if duration.isZero {
        return .init(outputs: [.number(toValue)],
                     willRunAgain: false)
    }
    
    // When project first opens, the output should be the toValue, like when we reset the graph.
    if areEquivalent(n: currentOutput, n2: toValue) {
        // log("classicAnimationEvalOpNumber: already at destination: classicAnimationState")
        // TODO: any reason to return `currentOutput` as opposed to the destination (`toValue`) ?
        return .init(outputs: [.number(currentOutput)],
                     willRunAgain: false)
    }
    
    var animationState = computedState.classicAnimationState?.asSingleState ?? .init()

//    // PROBABLY, THIS STARTS OUT AS EMPTY when project opens, causing
    let notYetInitialized = !animationState.initialValues.isDefined

    let goalChanged = animationState.initialValues
        .map { $0.goal != toValue } ?? false

    let shouldSetInitial =  notYetInitialized || goalChanged

    // Initializing or re-initializing the animation
    if shouldSetInitial {
        // Must set both frameCount and `start and goal`
        animationState.frameCount = 0 //
        animationState.initialValues = InitialAnimationValue(
            start: currentOutput,
            goal: toValue)
    }

    // Increment frameCount
    animationState.frameCount += 1

    let (newValue, shouldRunAgain) = runAnimation(
        toValue: toValue, //
        duration: duration,
        difference: animationState.initialValues?.difference ?? .zero,
        startValue: animationState.initialValues?.start ?? .zero,
        curve: values[safe: 2]?.getAnimationCurve ?? .linear,
        currentFrameCount: animationState.frameCount,
        fps: fps)

    if !shouldRunAgain {
        animationState = animationState.reset
    }

    computedState.classicAnimationState = .oneField(animationState)
    return .init(
        outputs: [.number(newValue)],
        willRunAgain: shouldRunAgain
    )
}
