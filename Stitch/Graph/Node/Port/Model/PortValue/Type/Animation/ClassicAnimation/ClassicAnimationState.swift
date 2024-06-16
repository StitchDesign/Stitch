//
//  ClassicAnimationState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/10/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// The starting conditions for
struct InitialAnimationValue: Equatable, Codable, Hashable {

    // The currentOutput when we first start the animation,
    // and which does not change as we progress,
    // even though currentOutput changes.
    let start: Double

    // Does not change during animation and always = toValue;
    // kept here for easier encapsulation of `difference`.
    let goal: Double

    // Represents the total original distance from start to end,
    // used for "how far progressed are we?" calculations.
    var difference: Double {
        goal - start
    }
}

// Used by .number and most other nodeTypes
struct OneFieldAnimationProgress: Equatable, Codable, Hashable {
    var frameCount: Int = 0

    // non-nil when actively animating;
    // never changes during a given animation,
    var initialValues: InitialAnimationValue?

    var reset: OneFieldAnimationProgress {
        var state = self
        state.frameCount = 0
        state.initialValues = nil
        return state
    }
}

/*
 For a multifield port-value type like .position,
 we treat each field x and y as if they are animating separately.

 Only when all fields have completed their animation,
 is the multifield animation done.

 Hence the need for a separate frameCount (ie animation step progress)
 for each field.
 */
struct TwoFieldAnimationProgress: Equatable, Codable, Hashable {
    var frameCountX: Int = 0
    var frameCountY: Int = 0

    var initialValuesX: InitialAnimationValue?
    var initialValuesY: InitialAnimationValue?

    var reset: TwoFieldAnimationProgress {
        var state = self
        state.frameCountX = 0
        state.frameCountY = 0
        state.initialValuesX = nil
        state.initialValuesY = nil
        return state
    }
}

struct ThreeFieldAnimationProgress: Equatable, Codable, Hashable {
    var frameCountX: Int = 0
    var frameCountY: Int = 0
    var frameCountZ: Int = 0

    var initialValuesX: InitialAnimationValue?
    var initialValuesY: InitialAnimationValue?
    var initialValuesZ: InitialAnimationValue?

    static let defaultState = Self()

    var reset: ThreeFieldAnimationProgress {
        var state = self
        state.frameCountX = 0
        state.frameCountY = 0
        state.frameCountZ = 0
        state.initialValuesX = nil
        state.initialValuesY = nil
        state.initialValuesZ = nil
        return state
    }
}

struct FourFieldAnimationProgress: Equatable, Codable, Hashable {
    var frameCountX: Int = 0 // for color: Red
    var frameCountY: Int = 0 // for color: Green
    var frameCountZ: Int = 0 // for color: Blue
    var frameCountW: Int = 0 // for color: Alpha

    var initialValuesX: InitialAnimationValue?
    var initialValuesY: InitialAnimationValue?
    var initialValuesZ: InitialAnimationValue?
    var initialValuesW: InitialAnimationValue?

    var reset: FourFieldAnimationProgress {
        var state = self

        state.frameCountX = 0
        state.frameCountY = 0
        state.frameCountZ = 0
        state.frameCountW = 0

        state.initialValuesX = nil
        state.initialValuesY = nil
        state.initialValuesZ = nil
        state.initialValuesW = nil

        return state
    }
}

// `single`, `double` etc. refer to how many different numbers we're separately animation
// single = we're tracking and animating a single number
// double = we're tracking and animating two different numbers,
// etc.
enum ClassicAnimationState: Equatable, Codable, Hashable {
    case oneField(OneFieldAnimationProgress),
         twoField(TwoFieldAnimationProgress),
         threeField(ThreeFieldAnimationProgress),
         fourField(FourFieldAnimationProgress)

    var resetAnimationProgress: ClassicAnimationState {
        switch self {
        case .oneField:
            return .oneField(OneFieldAnimationProgress())
        case .twoField:
            return .twoField(TwoFieldAnimationProgress())
        case .threeField:
            return .threeField(ThreeFieldAnimationProgress())
        case .fourField:
            return .fourField(FourFieldAnimationProgress())
        }
    }

    // See Patch.classicAnimation for the acceptable nodeTypes
    // for a ClassicAnimationNode
    static func defaultFromNodeType(_ nodeType: AnimationNodeType) -> Self {
        switch nodeType {
        // eg from Position to Number
        case .number:
            return .oneField(.init())
        // eg from Number to Position
        case .position, .size, .anchoring:
            return .twoField(.init())
        case .point3D:
            return .threeField(.init())
        // All other types use single field value
        case .color, .point4D:
            return .fourField(.init())
        }
    }
}
