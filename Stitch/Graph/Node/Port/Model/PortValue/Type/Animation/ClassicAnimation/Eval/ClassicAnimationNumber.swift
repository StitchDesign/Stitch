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

func classicAnimationEvalOpNumber(values: PortValues,
                                  computedState: ComputedNodeState,
                                  graphTime: TimeInterval,
                                  graphFrameCount: Int,
                                  fps: StitchFPS) -> ImpureEvalOpResult {

    // Doesn't change during animation itself;
    // ie if we change this, then a NEW animation starts.
    let toValue: Double = values.first?.getNumber ?? .zero

    // Our current output is always the 'starting point'
    // of a given animation step.
    let currentOutput: Double = values.last?.getNumber ?? toValue
    //    log("classicAnimationEvalOpNumber: currentOutput: \(currentOutput)")

    let duration: Double = values[safe: 1]?.getNumber ?? .zero

    if areEquivalent(n: currentOutput, n2: toValue)
        || duration.isZero {
        //        log("classicAnimationEvalOpNumber: already at destination: classicAnimationState: \(animationState)")
        return .init(outputs: [.number(currentOutput)],
                     willRunAgain: false)
    }

    var animationState = computedState.classicAnimationState?.asSingleState ?? .init()

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
