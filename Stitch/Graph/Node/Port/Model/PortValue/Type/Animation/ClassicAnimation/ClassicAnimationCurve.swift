//
//  AnimationHelpers.swift
//  prototype
//
//  Created by Christian J Clampitt on 8/17/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/*
 All our formulas are from here: https://gizma.com/easing/

 Good visualizations but irrelevant formulas?: https://easings.net/
 */

let defaultAnimationCurve = ClassicAnimationCurve.linear

// for `linear`:
// previously: 0.0001
let IS_SAME_DIFFERENCE_ALLOWANCE_LEGACY: CGFloat = 0.00001

// let IS_SAME_DIFFERENCE_ALLOWANCE: CGFloat = 0.0001
let IS_SAME_DIFFERENCE_ALLOWANCE: CGFloat = 0.001

extension ClassicAnimationCurve: PortValueEnum {
    static var portValueTypeGetter: PortValueTypeGetter<Self> {
        PortValue.animationCurve
    }

    var formula: AnimationCurveFormula {
        switch self {
        case .linear:
            return linearAnimation
        case .quadraticIn:
            return quadraticInAnimation
        case .quadraticOut:
            return quadraticOutAnimation
        case .quadraticInOut:
            return quadraticInOutAnimation

        case .sinusoidalIn:
            return sinusoidalInAnimation
        case .sinusoidalOut:
            return sinusoidalOutAnimation
        case .sinusoidalInOut:
            return sinusoidalInOutAnimation

        case .exponentialIn:
            return exponentialInAnimation
        case .exponentialOut:
            return exponentialOutAnimation
        case .exponentialInOut:
            return exponentialInOutAnimation
        }
    }
}

typealias AnimationCurveFormula = (Double, // t: current frame
                                   Double, // b: startValue,
                                   Double, // c: difference,
                                   // d: duration in frames
                                   Double) -> Double // result

/*
 Every animation value-type (eg .number, .position, .color etc.)
 is or can be broken down into a single numeric-returning calculation.

 Returns: `(newNumber: Double, shouldRunAgain: Bool)`
 */
func runAnimation(toValue: Double,
                  duration: Double,
                  difference: Double,
                  startValue: Double,
                  curve: ClassicAnimationCurve,
                  currentFrameCount: Int,
                  fps: StitchFPS) -> (Double, Bool) {

    runAnimationCurveFormula(formula: curve.formula,
                             duration: duration,
                             toValue: toValue,
                             startValue: startValue,
                             difference: difference,
                             currentFrame: currentFrameCount,
                             fps: fps)
}

// returns (newValue, runAgain?)
func runAnimationCurveFormula(formula: AnimationCurveFormula,
                              duration: Double, // in seconds
                              toValue: Double,
                              startValue: Double,
                              difference: Double,
                              currentFrame: Int,
                              fps: StitchFPS) -> (Double, Bool) {

    let animationFrameRate = classicAnimationFrame(fps)

    // let durationInFrames: CGFloat = duration * CLASSIC_ANIMATION_FRAMERATE
    let durationInFrames: CGFloat = duration * animationFrameRate

    let result = formula(currentFrame.toDouble,
                         startValue,
                         difference,
                         durationInFrames)

    let isSame: Bool = abs(toValue - result) < IS_SAME_DIFFERENCE_ALLOWANCE

    //    #if DEV_DEBUG
    //    log("runAnimationCurveFormula: animationFrameRate: \(animationFrameRate)")
    //    log("runAnimationCurveFormula: result: \(result)")
    //    let roundedValue = result.rounded(toPlaces: 5)
    //    log("runAnimationCurveFormula: roundedValue: \(roundedValue)")
    //    log("runAnimationCurveFormula: toValue.rounded(toPlaces: 5): \(toValue.rounded(toPlaces: 5))")
    //    log("abs(toValue.rounded(toPlaces: 5) - roundedValue): \(abs(toValue.rounded(toPlaces: 5) - roundedValue))")
    //    log("runAnimationCurveFormula: isSame: \(isSame)")
    //    #endif

    if isSame {
        //        log("runAnimationCurveFormula: will NOT run again")
        return (toValue.asPositiveZero, false)

    } else {
        //        log("runAnimationCurveFormula: will run again")
        return (result.asPositiveZero, true)
    }
}

extension ClassicAnimationCurve {
    var displayName: String {
        switch self {
        case .linear:
            return "Linear"
        case .quadraticIn:
            return "Quadratic In"
        case .quadraticOut:
            return "Quadratic Out"
        case .quadraticInOut:
            return "Quadratic In-Out"
        case .sinusoidalIn:
            return "Sinusoidal In"
        case .sinusoidalOut:
            return "Sinusoidal Out"
        case .sinusoidalInOut:
            return "Sinusoidal In-Out"
        case .exponentialIn:
            return "Exponential In"
        case .exponentialOut:
            return "Exponential Out"
        case .exponentialInOut:
            return "Exponential In-Out"
        }
    }
}
