//
//  ClassicAnimationColor.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/11/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension ClassicAnimationState {
    var asFourFieldState: FourFieldAnimationProgress {
        switch self {
        case .fourField(let x):
            return x
        default:
            #if DEV || DEV_DEBUG
            log("asFourFieldState: returning default state")
            #endif
            return .init()
        }
    }
}

func classicAnimationEvalOpColor(values: PortValues,
                                 computedState: ComputedNodeState,
                                 graphTime: TimeInterval,
                                 graphFrameCount: Int,
                                 fps: StitchFPS) -> ImpureEvalOpResult {

    let toValue: RGBA = values.first?.getColor?.asRGBA ?? RGBA(red: 0, green: 0, blue: 0, alpha: 1)
    let duration: Double = values[safe: 1]?.getNumber ?? .zero

    // Our current output is always the 'starting point'
    // of a given animation step.
    let currentOutput: RGBA = values.last?.getColor?.asRGBA ?? RGBA(red: 0, green: 0, blue: 0, alpha: 1)

    let equivalentRed = areEquivalent(n: currentOutput.red,
                                      n2: toValue.red)

    let equivalentBlue = areEquivalent(n: currentOutput.blue,
                                       n2: toValue.blue)

    let equivalentGreen = areEquivalent(n: currentOutput.green,
                                        n2: toValue.green)

    let equivalentAlpha = areEquivalent(n: currentOutput.alpha,
                                        n2: toValue.alpha)

    let equivalentColor = equivalentRed && equivalentBlue && equivalentGreen && equivalentAlpha

    if equivalentColor || duration.isZero {
        return .init(
            outputs: [.color(currentOutput.toColor)],
            willRunAgain: false
        )
    }

    var animationState = computedState.classicAnimationState?.asFourFieldState ?? .init()

    let shouldSetIntialRed = !animationState.initialValuesX.isDefined || animationState.initialValuesX!.goal != toValue.red

    let shouldSetIntialGreen = !animationState.initialValuesY.isDefined || animationState.initialValuesY!.goal != toValue.green

    let shouldSetIntialBlue = !animationState.initialValuesZ.isDefined || animationState.initialValuesZ!.goal != toValue.blue

    let shouldSetIntialAlpha = !animationState.initialValuesW.isDefined || animationState.initialValuesW!.goal != toValue.alpha

    // Initialize each field separately
    if shouldSetIntialRed {
        animationState.frameCountX = 0
        animationState.initialValuesX = InitialAnimationValue(
            start: currentOutput.red,
            goal: toValue.red)
    }
    if shouldSetIntialGreen {
        animationState.frameCountY = 0
        animationState.initialValuesY = InitialAnimationValue(
            start: currentOutput.green,
            goal: toValue.green)
    }

    if shouldSetIntialBlue {
        animationState.frameCountZ = 0
        animationState.initialValuesZ = InitialAnimationValue(
            start: currentOutput.blue,
            goal: toValue.blue)
    }

    if shouldSetIntialAlpha {
        animationState.frameCountW = 0
        animationState.initialValuesW = InitialAnimationValue(
            start: currentOutput.alpha,
            goal: toValue.alpha)
    }

    // Increment each field separately
    if !equivalentRed {
        animationState.frameCountX += 1
    }
    if !equivalentGreen {
        animationState.frameCountY += 1
    }
    if !equivalentBlue {
        animationState.frameCountZ += 1
    }
    if !equivalentAlpha {
        animationState.frameCountW += 1
    }

    let curve: ClassicAnimationCurve = values[2].getAnimationCurve!

    let (newValueRed, shouldRunAgainRed) = runAnimation(
        toValue: toValue.red,
        duration: duration,
        difference: animationState.initialValuesX!.difference,
        startValue: animationState.initialValuesX!.start,
        curve: curve,
        currentFrameCount: animationState.frameCountX,
        fps: fps)

    let (newValueGreen, shouldRunAgainGreen) = runAnimation(
        toValue: toValue.green,
        duration: duration,
        difference: animationState.initialValuesY!.difference,
        startValue: animationState.initialValuesY!.start,
        curve: curve,
        currentFrameCount: animationState.frameCountY,
        fps: fps)

    let (newValueBlue, shouldRunAgainBlue) = runAnimation(
        toValue: toValue.blue,
        duration: duration,
        difference: animationState.initialValuesZ!.difference,
        startValue: animationState.initialValuesZ!.start,
        curve: curve,
        currentFrameCount: animationState.frameCountZ,
        fps: fps)

    let (newValueAlpha, shouldRunAgainAlpha) = runAnimation(
        toValue: toValue.alpha,
        duration: duration,
        difference: animationState.initialValuesW!.difference,
        startValue: animationState.initialValuesW!.start,
        curve: curve,
        currentFrameCount: animationState.frameCountW,
        fps: fps)

    let shouldRunAgain = shouldRunAgainRed
        || shouldRunAgainGreen
        || shouldRunAgainBlue
        || shouldRunAgainAlpha

    if !shouldRunAgain {
        animationState = animationState.reset
    }

    computedState.classicAnimationState = .fourField(animationState)
    return .init(
        outputs: [.color(RGBA(red: newValueRed,
                              green: newValueGreen,
                              blue: newValueBlue,
                              alpha: newValueAlpha)
            .toColor)],
        willRunAgain: shouldRunAgain
    )
}
