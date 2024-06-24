//
//  MomentumAnimationState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/23.
//

import Foundation
import StitchSchemaKit

// NOTE: technically, `MomentumAnimationState` is used by both graph momentum and scroll node eval

// Stop if amplitude gets too small.
let GRAPH_MOMENTUM_AMPLITUDE_MINIMUM: CGFloat = 0.001

struct MomentumAnimationState: Equatable, Codable, Hashable {
    var shouldRunY = false
    var shouldRunX = false

    // Do we need to run this momentum?
    var shouldRun: Bool {
        self.shouldRunY || self.shouldRunX
    }

    var didYMomentumFinish: Bool {
        (self.stepY > GRAPH_MOMENTUM_END_STEP_COUNT)
            || self.amplitude.y.magnitude < GRAPH_MOMENTUM_AMPLITUDE_MINIMUM
    }

    // Shouldn't this also use `shouldRunX`?
    var didXMomentumFinish: Bool {
        (self.stepX > GRAPH_MOMENTUM_END_STEP_COUNT)
            || self.amplitude.x.magnitude < GRAPH_MOMENTUM_AMPLITUDE_MINIMUM
    }

    var stepY: CGFloat = 0
    var stepX: CGFloat = 0

    var amplitude: CGPoint = .zero // initialVelocity * scaleFactor
    var delta: CGPoint = .zero
}

func boundVelocity(velocity: CGFloat,
                   minVelocityMagnitude: CGFloat = GRAPH_MOMENTUM_MINIMUM_VELOCITY_MAGNITUDE,
                   maxVelocityMagnitude: CGFloat = GRAPH_MOMENTUM_MAXIMUM_VELOCITY_MAGNITUDE) -> CGFloat {

    var velocity = velocity

    let sign = { (n: CGFloat) in
        n * (velocity < 0 ? -1 : 1)
    }

    if velocity.magnitude < minVelocityMagnitude {
        velocity = sign(minVelocityMagnitude)
    } else if velocity.magnitude > maxVelocityMagnitude {
        velocity = sign(maxVelocityMagnitude)
    }
    return velocity
}

func calculateAmplitude(velocity: CGFloat, // scalar taken from UIKit
                        zoom: CGFloat,
                        dampFactor: CGFloat = GRAPH_MOMENTUM_VELOCITY_DAMP_FACTOR) -> CGFloat {

    /*
     Zoomed in == eg zoom of 0.5;
     Zoomed out == eg zoom of 1.5;

     When we are zoomed in, we are moving the graph less,
     and want a smaller amplitude.

     Thus scale factor is `1/zoom`.
     */
    let scaleFactor: CGFloat = 1 / zoom
    return boundVelocity(velocity: velocity / dampFactor) * scaleFactor
}

func startFreeScrollDimensionMomentum(_ state: FreeScrollDimensionMomentum,
                                      _ velocity: CGFloat) -> FreeScrollDimensionMomentum {
    var state = state

    state.shouldRun = velocity.magnitude > FREE_SCROLL_MOMENTUM_VELOCITY_THRESHOLD

    state.amplitude = calculateAmplitude(velocity: velocity,
                                         zoom: 1.0)
    return state
}

// Momentum starts when graph-drag/scroll ends.
func startMomentum(_ state: MomentumAnimationState,
                   _ zoom: CGFloat,
                   // from UIKit Pan gestureRecognizer
                   _ velocity: CGPoint,
                   threshold: CGFloat = GRAPH_MOMENTUM_VELOCITY_THRESHOLD) -> MomentumAnimationState {

    var state = state

    state.shouldRunX = velocity.x.magnitude > threshold
    state.shouldRunY = velocity.y.magnitude > threshold

    state.amplitude.x = calculateAmplitude(velocity: velocity.x, zoom: zoom)
    state.amplitude.y = calculateAmplitude(velocity: velocity.y, zoom: zoom)

    //    #if DEV_DEBUG
    //    log("\n startMomentum: zoom: \(zoom)")
    //    log("startMomentum: velocity.y.magnitude: \(velocity.y.magnitude)")
    //    log("startMomentum: velocity.x.magnitude: \(velocity.x.magnitude)")
    //    log("startMomentum: state.amplitude.y: \(state.amplitude.y)")
    //    log("startMomentum: state.amplitude.x: \(state.amplitude.x)")
    //    log("startMomentum: state.shouldRunY: \(state.shouldRunY)")
    //    log("startMomentum: state.shouldRunX: \(state.shouldRunX)")
    //    #endif

    return state
}

// Momentum runs while we're not dragging the graph.
// NOTE: X and Y direction momentum are handled separately,
// since we might have momentum in one axis but not the other.
struct MomentumRunResult: Equatable {
    // animation state with updated delta, amplitude etc.
    let momentumState: MomentumAnimationState
    // new x position for graphOffset.localPosition.width
    let x: CGFloat
    // new y position for graphOffset.localPosition.height
    let y: CGFloat
}

func runMomentum(_ state: MomentumAnimationState,
                 shouldRunX: Bool,
                 shouldRunY: Bool,
                 // eg graphOffset.localPosition.width
                 x: CGFloat,
                 // eg graphOffset.localPosition.height
                 y: CGFloat) -> MomentumRunResult {

    var state = state
    var x = x
    var y = y

    if shouldRunY {
        state.delta.y = state.amplitude.y / GRAPH_MOMENTUM_TIME_CONSTANT
        //        log("runMomentum: state.amplitude.y was: \(state.amplitude.y)")
        //        log("runMomentum: state.delta.y: \(state.delta.y)")

        y += state.delta.y
        state.amplitude.y -= state.delta.y
        state.stepY += 1
    }

    if shouldRunX {
        state.delta.x = state.amplitude.x / GRAPH_MOMENTUM_TIME_CONSTANT

        //        #if DEV_DEBUG
        //        log("runMomentum: state.amplitude.x was: \(state.amplitude.x)")
        //        log("runMomentum: state.delta.x: \(state.delta.x)")
        //        #endif

        x += state.delta.x
        state.amplitude.x -= state.delta.x
        state.stepX += 1
    }

    return MomentumRunResult(momentumState: state, x: x, y: y)
}

// Momentum is reset upon:
// - a new drag gesture, and/or
// - the end of the momentum-run.
func resetMomentum(_ state: MomentumAnimationState) -> MomentumAnimationState {

    var state = state

    state.shouldRunY = false
    state.shouldRunX = false

    state.stepY = .zero
    state.stepX = .zero

    state.amplitude = .zero
    state.delta = .zero

    return state
}
