//
//  ClassicAnimationFormulae.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/11/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// currentTime always = animation.graphStep / assumedFrameRate

// changeInValue = final goal - first starting point
// ie the value span of the entire animation
// eg 0 -> 10, and so = 10
// or eg 10 -> 0, and so = -10

// duration = the total time for the entire animation

// function (t, b, c, d) {
//          return c*t/d + b;
// };

/*
 Math.linearTween = function (t, b, c, d) {
 return c*t/d + b;
 };
 */

func linearAnimation(t: Double, // currentTime
                     b: Double, // startValue
                     c: Double, // change
                     // duration
                     d: Double) -> Double {
    return c * t / d + b
}

/*
 // quadratic easing in - accelerating from zero velocity

 Math.easeInQuad = function (t, b, c, d) {
 t /= d;
 return c*t*t + b;
 };
 */
func quadraticInAnimation(t: Double, // currentTime
                          b: Double, // startValue
                          c: Double, // change
                          // duration
                          d: Double) -> Double {
    var t = t
    t /= d
    return c*t*t + b
}

/*
 // quadratic easing out - decelerating to zero velocity

 Math.easeOutQuad = function (t, b, c, d) {
 t /= d;
 return -c * t*(t-2) + b;
 };
 */
func quadraticOutAnimation(t: Double, // currentTime
                           b: Double, // startValue
                           c: Double, // change
                           // duration
                           d: Double) -> Double {
    var t = t
    t /= d
    return -c * t*(t-2) + b
}

/*
 // quadratic easing in/out - acceleration until halfway, then deceleration

 Math.easeInOutQuad = function (t, b, c, d) {
 t /= d/2;
 if (t < 1) return c/2*t*t + b;
 t--;
 return -c/2 * (t*(t-2) - 1) + b;
 };
 */
func quadraticInOutAnimation(t: Double, // currentTime
                             b: Double, // startValue
                             c: Double, // change
                             // duration
                             d: Double) -> Double {
    var t = t
    t /= d/2
    if t < 1 {
        return c/2*t*t + b
    }
    t -= 1
    return -c/2 * (t*(t-2) - 1) + b
}

/*
 // sinusoidal easing in - accelerating from zero velocity

 Math.easeInSine = function (t, b, c, d) {
 return -c * Math.cos(t/d * (Math.PI/2)) + c + b;
 };
 */
func sinusoidalInAnimation(t: Double, // currentTime
                           b: Double, // startValue
                           c: Double, // change
                           // duration
                           d: Double) -> Double {
    -c * cos(t/d * (.pi/2)) + c + b
}

/*
 // sinusoidal easing out - decelerating to zero velocity

 Math.easeOutSine = function (t, b, c, d) {
 return c * Math.sin(t/d * (Math.PI/2)) + b;
 };
 */
func sinusoidalOutAnimation(t: Double, // currentTime
                            b: Double, // startValue
                            c: Double, // change
                            // duration
                            d: Double) -> Double {
    // does `sin` expect radians or degrees?
    c * sin(t/d * (.pi/2)) + b
}

/*
 // sinusoidal easing in/out - accelerating until halfway, then decelerating

 Math.easeInOutSine = function (t, b, c, d) {
 return -c/2 * (Math.cos(Math.PI*t/d) - 1) + b;
 };
 */
func sinusoidalInOutAnimation(t: Double, // currentTime
                              b: Double, // startValue
                              c: Double, // change
                              // duration
                              d: Double) -> Double {
    -c/2 * (cos(.pi * t/d) - 1) + b
}

/*
 // exponential easing in - accelerating from zero velocity

 Math.easeInExpo = function (t, b, c, d) {
 return c * Math.pow( 2, 10 * (t/d - 1) ) + b;
 };

 */
func exponentialInAnimation(t: Double, // currentTime
                            b: Double, // startValue
                            c: Double, // change
                            // duration
                            d: Double) -> Double {
    c * pow(2, 10 * (t/d - 1)) + b
}

/*
 // exponential easing out - decelerating to zero velocity

 Math.easeOutExpo = function (t, b, c, d) {
 return c * ( -Math.pow( 2, -10 * t/d ) + 1 ) + b;
 };

 */
func exponentialOutAnimation(t: Double, // currentTime
                             b: Double, // startValue
                             c: Double, // change
                             // duration
                             d: Double) -> Double {
    c * (-pow(2, -10 * t/d) + 1) + b
}

/*
 http://gizma.com/easing/#expo3

 // t = current time
 // b = start value (of whole animation?)
 // c = change in value (ie `difference`)?
 // d = duration

 Math.easeInOutExpo = function (t, b, c, d) {
 t /= d/2;
 if (t < 1) return c/2 * Math.pow( 2, 10 * (t - 1) ) + b;
 t--;
 return c/2 * ( -Math.pow( 2, -10 * t) + 2 ) + b;
 };
 */
func exponentialInOutAnimation(t: Double, // currentTime
                               b: Double, // startValue
                               c: Double, // change
                               // duration
                               d: Double) -> Double {
    var t = t
    t /= (d/2)

    if t < 1 {
        // https://developer.apple.com/documentation/foundation/1779833-pow
        // Swift.pow(x: Double, y: Int) -> Double
        let x = pow(2, (10 * (t - 1)))
        return (c/2) * x + b
    }

    t -= 1

    let k = -pow(2, -10 * t) + 2
    return (c/2) * k + b
}

extension ClassicAnimationCurve {

    static let defaultAnimationCurve = Stitch.defaultAnimationCurve

    // We re-use our `t, b, c, d` formula from animation,
    // but supply defaults for every value except `t`.
    /*
     Note: we're not sure whether this approach is 100% correct;
     */
    func asCurveFormulaProgress(_ currentTime: Double) -> Double {
        // TODO: switch `linear` formula over to this;
        // you should have tests here ?

        // start time = 0,
        // since formula expects progress between 0 and 1
        let b: Double = 0

        // change = current progress ?
        let c: Double =  1

        // length of animation
        let d: Double = 1 // how long?

        return self.formula(currentTime, b, c, d)

    }
}

struct ClassicAnimationFormulae_REPL: View {

    // 0.75 exponential
    var data: Double {
        let t: Double = 0.75 // current time
        let b: Double = 0 // start is always 0, since curve node's progress input expects a number s.t. [0, 1]
        let c: Double =  1 // 0.75 // change = current progress ?
        let d: Double = 1 // how long?
        return exponentialInAnimation(t: t, b: b, c: c, d: d)
    }

    // 0.5 exponential-in
    var data2: Double {
        let t: Double = 0.5 // current time
        let b: Double = 0
        let c: Double = 1 // 0.75 // change = current progress ?
        let d: Double = 1 // how long?

        return exponentialInAnimation(t: t, b: b, c: c, d: d)
    }

    var data3: Double {
        let t: Double = 0.25 // current time
        let b: Double = 0
        let c: Double =  1 // 0.75 // change = current progress ?
        let d: Double = 1 // how long?

        return exponentialInAnimation(t: t, b: b, c: c, d: d)
    }

    var data4: Double {
        let t: Double = 0.26 // current time
        let b: Double = 0
        let c: Double =  1 // 0.75 // change = current progress ?
        let d: Double = 1 // how long?

        return exponentialInAnimation(t: t, b: b, c: c, d: d)
    }

    // t = current time
    // b = start value (of whole animation?)
    // c = change in value (ie `difference`)?
    // d = duration
    func asCurve(t: Double) -> Double {

        let b: Double = 0 // 0 as the v
        let c: Double =  1 // 0.75 // change = current progress ?
        let d: Double = 1 // how long?

        return exponentialInAnimation(t: t, b: b, c: c, d: d)
    }

    var body: some View {
        VStack {
            //            Text("hello: 0.75: \(data)")
            //            Text("hello: 0.5: \(data2)")
            //            Text("hello: 0.25: \(data3)")
            //            Text("hello: 0.26: \(data4)")

            Text("0.25: \(asCurve(t: 0.25))")
            Text("0.26: \(asCurve(t: 0.26))")
            Text("0.27: \(asCurve(t: 0.27))")
            Text("0.28: \(asCurve(t: 0.28))")

            Text("0.9: \(asCurve(t: 0.9))")
            Text("0.91: \(asCurve(t: 0.91))")
            Text("0.92: \(asCurve(t: 0.92))")
            Text("0.93: \(asCurve(t: 0.93))")
            Text("0.94: \(asCurve(t: 0.94))")
            //            Text("0.95: \(asCurve(t: 0.95))")

            // Sees accurate even for values > 1
            Text("1.95: \(asCurve(t: 1.95))")

            //            Text("0.96: \(asCurve(t: 0.96))")

            //            Text("0.7: \(asCurve(t: 0.7))")
            //            Text("0.8: \(asCurve(t: 0.8))")
            //            Text("0.9: \(asCurve(t: 0.9))")
            //            Text("1: \(asCurve(t: 1))")

        }.scaleEffect(4)
    }
}

struct ClassicAnimationFormulae_REPL_Previews: PreviewProvider {
    static var previews: some View {
        ClassicAnimationFormulae_REPL()
    }
}
