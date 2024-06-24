//
//  ClassicAnimationPosition.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/11/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension ClassicAnimationState {
    var asDoubleState: TwoFieldAnimationProgress {
        switch self {
        case .twoField(let x):
            return x
        default:
            #if DEV || DEV_DEBUG
            log("asDoubleState: returning default state")
            #endif
            return .init()
        }
    }
}

func classicAnimationEvalOpPosition(values: PortValues,
                                    computedState: ComputedNodeState,
                                    graphTime: TimeInterval,
                                    graphFrameCount: Int,
                                    fps: StitchFPS) -> ImpureEvalOpResult {

    let toValue: StitchPosition = values.first?.getPosition ?? .zero
    let duration: Double = values[safe: 1]?.getNumber ?? .zero

    // Our current output is always the 'starting point'
    // of a given animation step.
    let currentOutput: StitchPosition = values.last?.getPosition ?? .zero
    log("\n \n classicAnimationEvalOpPosition: TOP: currentOutput: \(currentOutput)")

    let equivalentX = areEquivalent(n: currentOutput.width,
                                    n2: toValue.width)

    let equivalentY = areEquivalent(n: currentOutput.height,
                                    n2: toValue.height)

    let equivalentPositions = equivalentX && equivalentY

    if equivalentPositions || duration.isZero {
        log("classicAnimationEvalOpPosition: done...")
        return .init(
            outputs: [.position(currentOutput)],
            willRunAgain: false
        )
    }

    var animationState = computedState.classicAnimationState?.asDoubleState ?? .init()

    let shouldSetIntialX = !animationState.initialValuesX.isDefined || animationState.initialValuesX?.goal != toValue.width

    let shouldSetIntialY = !animationState.initialValuesY.isDefined || animationState.initialValuesY?.goal != toValue.height

    // Initialize each field separately
    if shouldSetIntialX {
        log("defining initial x values...")
        animationState.frameCountX = 0
        animationState.initialValuesX = InitialAnimationValue(
            start: currentOutput.width,
            goal: toValue.width)
    }

    if shouldSetIntialY {
        log("defining initial y values...")
        animationState.frameCountY = 0
        animationState.initialValuesY = InitialAnimationValue(
            start: currentOutput.height,
            goal: toValue.height)
    }

    // Increment each field separately
    if !equivalentX {
        animationState.frameCountX += 1
    }
    if !equivalentY {
        animationState.frameCountY += 1
    }

    let curve = values[2].getAnimationCurve!

    let (newValueX, shouldRunAgainX) = runAnimation(
        toValue: toValue.width,
        duration: duration,
        difference: animationState.initialValuesX?.difference ?? .zero,
        startValue: animationState.initialValuesX?.start ?? .zero,
        curve: curve,
        currentFrameCount: animationState.frameCountX,
        fps: fps)

    let (newValueY, shouldRunAgainY) = runAnimation(
        toValue: toValue.height,
        duration: duration,
        difference: animationState.initialValuesY?.difference ?? .zero,
        startValue: animationState.initialValuesY?.start ?? .zero,
        curve: curve,
        currentFrameCount: animationState.frameCountY,
        fps: fps)

    let shouldRunAgain = shouldRunAgainX || shouldRunAgainY

    if !shouldRunAgain {
        animationState = animationState.reset
    }

    computedState.classicAnimationState = .twoField(animationState)
    return .init(
        outputs: [.position(StitchPosition(width: newValueX,
                                 height: newValueY))],
        willRunAgain: shouldRunAgain
    )
}
