//
//  ClassicAnimationOpSize.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/20/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO: if this pattern repeats, abstract it out
func classicAnimationEvalOpSize(values: PortValues,
                                    computedState: ComputedNodeState,
                                    graphTime: TimeInterval,
                                    graphFrameCount: Int,
                                    fps: StitchFPS) -> ImpureEvalOpResult {

    let toValue: LayerSize = values.first?.getSize ?? .zero
    let duration: Double = values[safe: 1]?.getNumber ?? .zero

    // Our current output is always the 'starting point'
    // of a given animation step.
    let currentOutput: LayerSize = values.last?.getSize ?? .zero
    log("\n \n classicAnimationEvalOpSize: TOP: currentOutput: \(currentOutput)")
    
    let equivalentX = areEquivalent(n: currentOutput.width.asNumber,
                                    n2: toValue.width.asNumber)

    let equivalentY = areEquivalent(n: currentOutput.height.asNumber,
                                    n2: toValue.height.asNumber)

    let equivalentPositions = equivalentX && equivalentY

    if equivalentPositions || duration.isZero {
        log("classicAnimationEvalOpSize: done...")
        return .init(
            outputs: [.size(currentOutput)],
            willRunAgain: false
        )
    }

    var animationState = computedState.classicAnimationState?.asDoubleState ?? .init()

    let shouldSetIntialX = !animationState.initialValuesX.isDefined || animationState.initialValuesX?.goal != toValue.width.asNumber

    let shouldSetIntialY = !animationState.initialValuesY.isDefined || animationState.initialValuesY?.goal != toValue.height.asNumber

    // Initialize each field separately
    if shouldSetIntialX {
        log("defining initial x values...")
        animationState.frameCountX = 0
        animationState.initialValuesX = InitialAnimationValue(
            start: currentOutput.width.asNumber,
            goal: toValue.width.asNumber)
    }

    if shouldSetIntialY {
        log("defining initial y values...")
        animationState.frameCountY = 0
        animationState.initialValuesY = InitialAnimationValue(
            start: currentOutput.height.asNumber,
            goal: toValue.height.asNumber)
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
        toValue: toValue.width.asNumber,
        duration: duration,
        difference: animationState.initialValuesX?.difference ?? .zero,
        startValue: animationState.initialValuesX?.start ?? .zero,
        curve: curve,
        currentFrameCount: animationState.frameCountX,
        fps: fps)

    let (newValueY, shouldRunAgainY) = runAnimation(
        toValue: toValue.height.asNumber,
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
        outputs: [.size(LayerSize(width: newValueX,
                                  height: newValueY))],
        willRunAgain: shouldRunAgain
    )
}
