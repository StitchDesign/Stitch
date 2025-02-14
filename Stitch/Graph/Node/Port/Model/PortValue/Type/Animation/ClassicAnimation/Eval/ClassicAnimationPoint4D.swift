//
//  ClassicAnimationPoint4D.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/20/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO: if this pattern repeats again, just factor it out -- need to return different defaults (PortValue.color vs .point4D) and unwrap different values
func classicAnimationEvalOpPoint4D(values: PortValues,
                                   computedState: ComputedNodeState,
                                   graphTime: TimeInterval,
                                   graphFrameCount: Int,
                                   fps: StitchFPS) -> ImpureEvalOpResult {

    let toValue: Point4D = values.first?.getPoint4D ?? .zero
    let duration: Double = values[safe: 1]?.getNumber ?? .zero

    // Our current output is always the 'starting point'
    // of a given animation step.
    let currentOutput: Point4D = graphTime.graphJustStarted ? toValue : values.last?.getPoint4D ?? .zero

    let equivalentX = areEquivalent(n: currentOutput.x,
                                      n2: toValue.x)

    let equivalentY = areEquivalent(n: currentOutput.y,
                                        n2: toValue.y)

    let equivalentZ = areEquivalent(n: currentOutput.z,
                                       n2: toValue.z)
    
    let equivalentW = areEquivalent(n: currentOutput.w,
                                        n2: toValue.w)

    let equivalentOverall = equivalentX && equivalentZ && equivalentY && equivalentW

    if equivalentOverall || duration.isZero {
        return .init(
            outputs: [.point4D(currentOutput)],
            willRunAgain: false
        )
    }

    var animationState = computedState.classicAnimationState?.asFourFieldState ?? .init()

    let shouldSetIntialX = !animationState.initialValuesX.isDefined || animationState.initialValuesX!.goal != toValue.x

    let shouldSetIntialY = !animationState.initialValuesY.isDefined || animationState.initialValuesY!.goal != toValue.y

    let shouldSetIntialZ = !animationState.initialValuesZ.isDefined || animationState.initialValuesZ!.goal != toValue.z

    let shouldSetIntialW = !animationState.initialValuesW.isDefined || animationState.initialValuesW!.goal != toValue.w

    // Initialize each field separately
    if shouldSetIntialX {
        animationState.frameCountX = 0
        animationState.initialValuesX = InitialAnimationValue(
            start: currentOutput.x,
            goal: toValue.x)
    }
    if shouldSetIntialY {
        animationState.frameCountY = 0
        animationState.initialValuesY = InitialAnimationValue(
            start: currentOutput.y,
            goal: toValue.y)
    }

    if shouldSetIntialZ {
        animationState.frameCountZ = 0
        animationState.initialValuesZ = InitialAnimationValue(
            start: currentOutput.z,
            goal: toValue.z)
    }

    if shouldSetIntialW {
        animationState.frameCountW = 0
        animationState.initialValuesW = InitialAnimationValue(
            start: currentOutput.w,
            goal: toValue.w)
    }

    // Increment each field separately
    if !equivalentX {
        animationState.frameCountX += 1
    }
    if !equivalentY {
        animationState.frameCountY += 1
    }
    if !equivalentZ {
        animationState.frameCountZ += 1
    }
    if !equivalentW {
        animationState.frameCountW += 1
    }

    let curve: ClassicAnimationCurve = values[2].getAnimationCurve!

    let (newValueX, shouldRunAgainX) = runAnimation(
        toValue: toValue.x,
        duration: duration,
        difference: animationState.initialValuesX!.difference,
        startValue: animationState.initialValuesX!.start,
        curve: curve,
        currentFrameCount: animationState.frameCountX,
        fps: fps)

    let (newValueY, shouldRunAgainY) = runAnimation(
        toValue: toValue.y,
        duration: duration,
        difference: animationState.initialValuesY!.difference,
        startValue: animationState.initialValuesY!.start,
        curve: curve,
        currentFrameCount: animationState.frameCountY,
        fps: fps)

    let (newValueZ, shouldRunAgainZ) = runAnimation(
        toValue: toValue.z,
        duration: duration,
        difference: animationState.initialValuesZ!.difference,
        startValue: animationState.initialValuesZ!.start,
        curve: curve,
        currentFrameCount: animationState.frameCountZ,
        fps: fps)

    let (newValueW, shouldRunAgainW) = runAnimation(
        toValue: toValue.w,
        duration: duration,
        difference: animationState.initialValuesW!.difference,
        startValue: animationState.initialValuesW!.start,
        curve: curve,
        currentFrameCount: animationState.frameCountW,
        fps: fps)

    let shouldRunAgain = shouldRunAgainX
        || shouldRunAgainY
        || shouldRunAgainZ
        || shouldRunAgainW

    if !shouldRunAgain {
        animationState = animationState.reset
    }

    computedState.classicAnimationState = .fourField(animationState)
    return .init(
        outputs: [.point4D(Point4D(x: newValueX,
                                   y: newValueY,
                                   z: newValueZ,
                                   w: newValueW))],
        willRunAgain: shouldRunAgain
    )
}

