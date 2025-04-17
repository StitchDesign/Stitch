//
//  SpringAnimationState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/29/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

final class SpringAnimationState: NodeEphemeralObservable {
    // nil = not initialized; animation not running
    var springStates: [SpringValueState?] = []

    func onPrototypeRestart(document: StitchDocumentViewModel) {
        self.reset()
    }
    
    func reset() {
        self.springStates = []
    }
}

// When spring's velocity is <= this epsilon,
// the spring animation is complete.
let SPRING_ANIMATION_VELOCITY_EPSILON = 0.0002 // feels best?

let SPRING_ANIMATION_60_FPS_STEP_SIZE = 0.01666667
let SPRING_ANIMATION_120_FPS_STEP_SIZE = 0.00833333

#if targetEnvironment(macCatalyst)
let SPRING_ANIMATION_STEP_SIZE = SPRING_ANIMATION_60_FPS_STEP_SIZE
#else
// let SPRING_ANIMATION_STEP_SIZE = SPRING_ANIMATION_120_FPS_STEP_SIZE
let SPRING_ANIMATION_STEP_SIZE = SPRING_ANIMATION_60_FPS_STEP_SIZE
#endif

struct SpringValueState {
    // Must be remade whenever Mass, Friction (Damping) or Tension (Stiffness) change
    var spring: Spring

    // Represents progress of the animation;
    // Note: we can't base this off of graphTime, since we can get big jumps in graphTime steps
    // We instead start at 0 and add platform-FPS-stepSize on each step.
    var stepTime: TimeInterval = .zero

    var fromValue: Double

    // needed to detect when user changes toValue input during animation
    var toValue: Double

    // animation stops when currentVelocity is less than some epsilon
    var currentVelocity: Double = .zero
}
