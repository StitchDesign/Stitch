//
//  CubicBezierAnimationNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/3/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// let CUBIC_BEZIER_FRAMERATE: Double = 1/60

struct CubicBezierAnimationNode: PatchNodeDefinition {
    static let patch = Patch.cubicBezierAnimation

    static let defaultUserVisibleType: UserVisibleType? = .number

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [.number(0)],
                    label: "Number"
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "Duration"
                ),
                .init(
                    defaultValues: [.number(0.17)],
                    label: "1st Control Point X"
                ),
                .init(
                    defaultValues: [.number(0.17)],
                    label: "1st Control Point Y"
                ),
                .init(
                    defaultValues: [.number(0)],
                    label: "2nd Control Point X"
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "2nd Control Point y"
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: .number
                ),
                .init(
                    label: "Path",
                    type: .position
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        let state: ClassicAnimationState = .threeField(ThreeFieldAnimationProgress())
        return ComputedNodeState(classicAnimationState: state)
    }
}

@MainActor
func cubicBezierAnimationEval(node: PatchNode,
                              state: GraphStepState) -> ImpureEvalResult {

    node.loopedEval(ComputedNodeState.self) { values, computedState, index in
        cubicBezierAnimationEvalOp(
            values: values,
            computedState: computedState,
            fps: state.estimatedFPS)
    }
    .toImpureEvalResult()//defaultOutputs: [[defaultNumber], [defaultNumber]])
}

/*
 Note: Cubic Bezier Node has two outputs (vs Classic Animation Node's one),
 but reuses the `.triple` animation state, i.e. an animation state that can track three different fields,
 each field with its own step-count etc.

 `.triple` was originally meant for ClassicAnimation with Point3D.
 */
func cubicBezierAnimationEvalOp(values: PortValues,
                                computedState: ComputedNodeState,
                                fps: StitchFPS) -> ImpureEvalOpResult {

    let toValue: Double = values.first!.getNumber!
    let duration: Double = values[1].getNumber!

    let firstControlPointX = values[2].getNumber!
    let firstControlPointY = values[3].getNumber!
    let firstControlPoint: CGPoint = .init(x: firstControlPointX,
                                           y: firstControlPointY)

    let secondControlPointX = values[4].getNumber!
    let secondControlPointY = values[5].getNumber!
    let secondControlPoint: CGPoint = .init(x: secondControlPointX,
                                            y: secondControlPointY)

    let currentOutput: Double = values[safe: 6]?.getNumber ?? toValue
    let currentOutput2: StitchPosition = values.last?.getPosition ?? .zero

    let equivalentX = areEquivalent(n: currentOutput2.width,
                                    n2: toValue)

    let equivalentY = areEquivalent(n: currentOutput2.height,
                                    n2: toValue)

    let equivalentZ = areEquivalent(n: currentOutput,
                                    n2: toValue)

    let equivalentPositions = equivalentX && equivalentY && equivalentZ

    let finished = ImpureEvalOpResult(
        outputs: [PortValue.number(currentOutput),
                  PortValue.position(.init(width: currentOutput,
                                           height: currentOutput))],
        willRunAgain: false
    )

    if equivalentPositions || duration.isZero {
        log("cubicBezierAnimationEvalOp: reached positions or duration was 0")
        return finished
    }

    // Independent of 'single vs multiple' field etc.
    guard case var .threeField(animationState) = computedState.classicAnimationState else {
        log("cubicBezierAnimationEvalOp: bad state")
        fatalError()
    }

    let shouldSetIntialX = !animationState.initialValuesX.isDefined || animationState.initialValuesX!.goal != toValue

    let shouldSetIntialY = !animationState.initialValuesY.isDefined || animationState.initialValuesY!.goal != toValue

    let shouldSetIntialZ = !animationState.initialValuesZ.isDefined || animationState.initialValuesZ!.goal != toValue

    // Initialize each field separately
    if shouldSetIntialX {
        animationState.frameCountX = 0
        animationState.initialValuesX = InitialAnimationValue(
            start: currentOutput2.width,
            goal: toValue)
    }
    if shouldSetIntialY {
        animationState.frameCountY = 0
        animationState.initialValuesY = InitialAnimationValue(
            start: currentOutput2.height,
            goal: toValue)
    }

    if shouldSetIntialZ {
        animationState.frameCountZ = 0
        animationState.initialValuesZ = InitialAnimationValue(
            start: currentOutput,
            goal: toValue)
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

    // Technically only need to use one frame count, since all parts of cubic bezier runs on a single frame:
    // When duration changes, the `by` changes,
    // but we still always stride 0 -> 1.
    // (`frameCount` always starts at 0.)
    #if targetEnvironment(macCatalyst)
    let frameRate: CGFloat = 1/60 // heuristic: MacBook Air runs at 60 FPS
    #else
    let frameRate: CGFloat = 1/120 // heuristic: iPad Pro runs at 120 FPS
    #endif

    // TODO: use device's actual / estimated FPS, instead of assuming based on iOS vs Catalyst
    // let frameRate: CGFloat = 1/fps.value

    let by = frameRate * 1/duration

    let thisStep = animationState.frameCountZ.toDouble * by

    if thisStep > 1.0 {
        log("cubicBezierAnimationEvalOp: reached enough steps: \(thisStep)")
        // Need to reset the animationState too
        animationState = animationState.reset
        computedState.classicAnimationState = .threeField(animationState)
        return finished
    }

    let (newOutput, newOutput2) = cubicBezierProgress(
        start: animationState.initialValuesZ!.start,
        end: toValue,
        firstControlPoint: firstControlPoint,
        secondControlPoint: secondControlPoint,
        duration: duration,
        thisStep: thisStep)

    computedState.classicAnimationState = .threeField(animationState)
    return .init(
        outputs: [.number(newOutput), // first output,
                  .position(newOutput2.toCGSize)], // second output
        willRunAgain: true
    )
}

// returns:
//  (percentage progress along cubic bezier curve,
//   2D point at progress along curve)
func cubicBezierProgress(start: CGFloat,
                         end: CGFloat,
                         firstControlPoint: CGPoint,
                         secondControlPoint: CGPoint,
                         duration: CGFloat,
                         thisStep: CGFloat) -> (Double, CGPoint) {

    // start and end are always 0 and 1
    let p0: CGPoint = .zero // start
    let p3: CGPoint = .init(x: 1, y: 1) // end

    // Control points
    // (Don't need to be between 0 and 1 ?)
    let p1: CGPoint = firstControlPoint
    let p2: CGPoint = secondControlPoint

    let xResult = Stitch.transition(
        cubicBezierN(t: thisStep, n0: p0.x, n1: p1.x, n2: p2.x, n3: p3.x),
        start: start,
        end: end)

    let yResult = Stitch.transition(
        cubicBezierN(t: thisStep, n0: p0.y, n1: p1.y, n2: p2.y, n3: p3.y),
        start: start,
        end: end)

    let resultPoint = CGPoint(x: xResult, y: yResult)

    // the current step as a matter of progress
    // a number within interveral [0, 1]
    let progress = Stitch.progress(thisStep, start: 0, end: 1)

    let progressAlongCurve = cubicBezierJS(
        p1x: p1.x,
        p1y: p1.y,
        p2x: p2.x,
        p2y: p2.y,
        x: progress,
        // cubicBezier progress-along-curve formula expects time in milliseconds
        duration: duration * 1000)

    let resultNumber = Stitch.transition(progressAlongCurve,
                                         start: start,
                                         end: end)

    //    log("cubicBezierProgress: progress: \(progress)")
    //    log("cubicBezierProgress: progressAlongCurve: \(progressAlongCurve)")
    //    log("cubicBezierProgress: resultNumber: \(resultNumber)")
    //    log("cubicBezierProgress: resultPoint: \(resultPoint)")

    return (resultNumber, resultPoint)
}
