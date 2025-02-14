//
//  ClassicAnimationPoint3D.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/11/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension ClassicAnimationState {
    var asThreeFieldState: ThreeFieldAnimationProgress {
        switch self {
        case .threeField(let x):
            return x
        default:
            #if DEV || DEV_DEBUG
            log("asThreeFieldState: returning default state")
            #endif
            return .init()
        }
    }
}

func classicAnimationEvalOpPoint3D(values: PortValues,
                                   computedState: ComputedNodeState,
                                   graphTime: TimeInterval,
                                   graphFrameCount: Int,
                                   fps: StitchFPS) -> ImpureEvalOpResult {

    let toValue: Point3D = values.first?.getPoint3D ?? .zero
    let duration: Double = values[safe: 1]?.getNumber ?? .zero

    // Our current output is always the 'starting point'
    // of a given animation step.
    let currentOutput: Point3D = graphTime.graphJustStarted ? toValue : values.last?.getPoint3D ?? .zero

    let equivalentX = areEquivalent(n: currentOutput.x,
                                    n2: toValue.x)

    let equivalentY = areEquivalent(n: currentOutput.y,
                                    n2: toValue.y)

    let equivalentZ = areEquivalent(n: currentOutput.z,
                                    n2: toValue.z)

    let equivalentPositions = equivalentX && equivalentY && equivalentZ

    if equivalentPositions || duration.isZero {
        return .init(outputs: [.point3D(currentOutput)],
                     willRunAgain: false)
    }

    // Independent of 'single vs multiple' field etc.
    var animationState: ThreeFieldAnimationProgress = computedState.classicAnimationState?.asThreeFieldState ?? .init()

    let shouldSetIntialX = !animationState.initialValuesX.isDefined || animationState.initialValuesX!.goal != toValue.x

    let shouldSetIntialY = !animationState.initialValuesY.isDefined || animationState.initialValuesY!.goal != toValue.y

    let shouldSetIntialZ = !animationState.initialValuesZ.isDefined || animationState.initialValuesZ!.goal != toValue.z

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

    let curve: ClassicAnimationCurve = values[safe: 2]?.getAnimationCurve ?? .linear

    let (newValueX, shouldRunAgainX) = runAnimation(
        toValue: toValue.x,
        duration: duration,
        difference: animationState.initialValuesX?.difference ?? .zero,
        startValue: animationState.initialValuesX?.start ?? .zero,
        curve: curve,
        currentFrameCount: animationState.frameCountX,
        fps: fps)

    let (newValueY, shouldRunAgainY) = runAnimation(
        toValue: toValue.y,
        duration: duration,
        difference: animationState.initialValuesY?.difference ?? .zero,
        startValue: animationState.initialValuesY?.start ?? .zero,
        curve: curve,
        currentFrameCount: animationState.frameCountY,
        fps: fps)

    let (newValueZ, shouldRunAgainZ) = runAnimation(
        toValue: toValue.z,
        duration: duration,
        difference: animationState.initialValuesZ?.difference ?? .zero,
        startValue: animationState.initialValuesZ?.start ?? .zero,
        curve: curve,
        currentFrameCount: animationState.frameCountZ,
        fps: fps)

    let shouldRunAgain = shouldRunAgainX
        || shouldRunAgainY
        || shouldRunAgainZ

    if !shouldRunAgain {
        animationState = animationState.reset
    }

    computedState.classicAnimationState = .threeField(animationState)
    return .init(
        outputs: [.point3D(Point3D(x: newValueX,
                         y: newValueY,
                         z: newValueZ))],
        willRunAgain: shouldRunAgain
    )
}
