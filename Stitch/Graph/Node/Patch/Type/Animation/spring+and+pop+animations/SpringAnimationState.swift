//
//  SpringAnimationState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/29/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct SpringAnimationValues: Equatable, Hashable {
    // nil = not initialized; animation not running
    var springValues: SpringValues?
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

struct SpringValues: Equatable, Hashable {
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

// single field animation
// e.g. Number
struct OneFieldSpringAnimation: Equatable, Hashable {
    var values = SpringAnimationValues()
}

// e.g. Position
struct TwoFieldSpringAnimation: Equatable, Hashable {
    var valuesX = SpringAnimationValues()
    var valuesY = SpringAnimationValues()
}

enum SpringAnimationState: Equatable, Hashable {
    case one(OneFieldSpringAnimation),
         two(TwoFieldSpringAnimation)

    // is this the proper way to reset a spring animation's progress?
    var resetSpringAnimation: SpringAnimationState {
        switch self {
        case .one:
            return .one(.init())
        case .two:
            return .two(.init())
        }
    }
}

