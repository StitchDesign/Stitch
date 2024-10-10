//
//  ClassicAnimation.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/1/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Assumed
// let CLASSIC_ANIMATION_FRAMERATE: Double = 30.0

// #if !targetEnvironment(macCatalyst)
//// run long on iPad
// let CLASSIC_ANIMATION_FRAMERATE: Double = 60
// #else
// let CLASSIC_ANIMATION_FRAMERATE: Double = 30
// #endif

func classicAnimationFrame(_ fps: StitchFPS) -> CGFloat {

    // TODO: fix classic animation such that it completes exactly at the specific duration
    // TODO: use the device's real, actual FPS (which may be e.g. less than 60 FPS on a MacBook Air)
    // asClassicAnimationFrameRate(fpsAlongSpectrum(fps))

    #if targetEnvironment(macCatalyst)
    // return 30
    return 60
    #else
    // return 60
    return 120
    #endif
}

// TODO: debug why, per Playgrounds, using `0` and `60` instead of the `Double` variables makes a difference
let STITCH_MIN_CLASSIC_ANIMATION_FRAME_RATE: Double = 0
let STITCH_MAX_CLASSIC_ANIMATION_FRAME_RATE: Double = 60

/// n: some progress value, i.e. n such that (0, 1)
func asClassicAnimationFrameRate(_ n: Double) -> Double {
    //    let rate = transition(n,
    //                          start: STITCH_MIN_CLASSIC_ANIMATION_FRAME_RATE, // 0 FPS
    //                          end: STITCH_MAX_CLASSIC_ANIMATION_FRAME_RATE) // 120 FPS

    let rate = transition(n,
                          start: 0, // 0 FPS
                          end: 60) // 120 FPS

    if rate < 0 {
        return  1 // 1 vs 0 ?
    } else if rate > 60 {
        return 60
    } else {
        return rate
    }
}

let classicAnimationDefaultDuration: Double = 1
let classicAnimationDefaultCurve: ClassicAnimationCurve = .linear

struct ClassicAnimationNode: PatchNodeDefinition {
    static let patch: Patch = .classicAnimation

    static private let _defaultUserVisibleType: UserVisibleType = .number
    static let defaultUserVisibleType: UserVisibleType? = Self._defaultUserVisibleType

    static func rowDefinitions(for type: UserVisibleType?) -> NodeRowDefinitions {
        .init(
            inputs: [
                .init(
                    defaultValues: [defaultNumber],
                    label: "Number"
                ),
                .init(
                    defaultValues: [.number(1)],
                    label: "Duration",
                    isTypeStatic: true
                ),
                .init(
                    defaultValues: [.animationCurve(.linear)],
                    label: "Curve",
                    isTypeStatic: true
                )
            ],
            outputs: [
                .init(
                    label: "",
                    type: type ?? .number
                )
            ]
        )
    }

    static func createEphemeralObserver() -> NodeEphemeralObservable? {
        // If we have existing inputs, then we're deserializing,
        // and should base internal state and starting outputs on those inputs.
        let state = ClassicAnimationState.defaultFromNodeType(.fromNodeType(Self._defaultUserVisibleType))

        return ComputedNodeState(classicAnimationState: state)
    }
}

@MainActor
func classicAnimationEval(node: PatchNode,
                          state: GraphStepState) -> ImpureEvalResult {
    
//    let inputs = node.inputs
//    let outputs = node.outputs
//    let animationStates: [ClassicAnimationState] = node.computedStates?.compactMap {
//        $0.classicAnimationState
//    } ?? []
    let fps = state.estimatedFPS

    return node.loopedEval(ComputedNodeState.self) { values, computedState, index in
        
        // We must have a userVisibleType on a classic animation node
        guard let evalType: AnimationNodeType = node.userVisibleType.map(AnimationNodeType.fromNodeType) else {
            log("classicAnimationEval: had invalide node type: \(node.userVisibleType)")
            #if DEBUG
            fatalError() // we were assigned some false or bad type
            #endif
            return ImpureEvalOpResult(outputs: [.number(.zero)])
        }
        
        switch evalType {
            
        case .number:
            return classicAnimationEvalOpNumber(
                values: values,
                computedState: computedState,
                graphTime: state.graphTime,
                graphFrameCount: state.graphFrameCount,
                fps: fps)
        case .anchoring:
            return classicAnimationEvalOpAnchoring(
                values: values,
                computedState: computedState,
                graphTime: state.graphTime,
                graphFrameCount: state.graphFrameCount,
                fps: fps)
        case .position:
            return classicAnimationEvalOpPosition(
                values: values,
                computedState: computedState,
                graphTime: state.graphTime,
                graphFrameCount: state.graphFrameCount,
                fps: fps)
        case .size:
            return classicAnimationEvalOpSize(
                values: values,
                computedState: computedState,
                graphTime: state.graphTime,
                graphFrameCount: state.graphFrameCount,
                fps: fps)
        case .point3D:
            return classicAnimationEvalOpPoint3D(
                values: values,
                computedState: computedState,
                graphTime: state.graphTime,
                graphFrameCount: state.graphFrameCount,
                fps: fps)
        case .color:
            return classicAnimationEvalOpColor(
                values: values,
                computedState: computedState,
                graphTime: state.graphTime,
                graphFrameCount: state.graphFrameCount,
                fps: fps)
        case .point4D:
            return classicAnimationEvalOpPoint4D(
                values: values,
                computedState: computedState,
                graphTime: state.graphTime,
                graphFrameCount: state.graphFrameCount,
                fps: fps)
        }
    }
    .toImpureEvalResult()
}
