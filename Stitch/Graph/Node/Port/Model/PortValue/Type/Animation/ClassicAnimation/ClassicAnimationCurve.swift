//
//  AnimationHelpers.swift
//  Stitch
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
  can be decomposed into a single numeric-returning calculation.

 Returns: `(newNumber: Double, shouldRunAgain: Bool)`
 */
func runAnimation(toValue: Double,
                  duration: Double,
                  difference: Double,
                  startValue: Double,
                  curve: ClassicAnimationCurve,
                  currentFrameCount: Int,
                  fps: StitchFPS) -> (Double, Bool) {
    
    let formula = curve.formula
    let currentFrame = currentFrameCount
    
    let animationFrameRate = classicAnimationFrame(fps)

    // let durationInFrames: CGFloat = duration * CLASSIC_ANIMATION_FRAMERATE
    let durationInFrames: CGFloat = duration * animationFrameRate

    let result = formula(currentFrame.toDouble,
                         startValue,
                         difference,
                         durationInFrames)
    
    // HACK: If duration < 0.1, stop when currentFrame has passed the expected duration
    // TODO: smarter way to prevent some animations (linear, etc.) from continuing indefinitely when duration < 0.1
    // TODO: can we leverage SwiftUI's `Animation.animate(value:time:context:)` ?
    if duration < 0.1,
       currentFrame.toDouble > durationInFrames{
        return (toValue.asPositiveZero, false)
    }
    
    
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
