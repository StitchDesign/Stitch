//
//  CubicBezierUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/5/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// MARK: FINDING THE 2D LOCATION ALONG THE CURVE

// https://math.stackexchange.com/q/26846
func cubicBezierN(t: CGFloat,
                  n0: CGFloat,
                  n1: CGFloat,
                  n2: CGFloat,
                  n3: CGFloat) -> CGFloat {
    pow(1 - t, 3) * n0 +
        3 * pow(1 - t, 2) * t * n1 +
        3 * (1 - t) * pow(t, 2) * n2 +
        pow(t, 3) * n3
}

// MARK: FINDING PERCENTAGE PROGRESS ALONG THE CURVE

// https://gist.github.com/mckamey/3783009

/*
 /**
 * @param p1x {number} X component of control point 1
 * @param p1y {number} Y component of control point 1
 * @param p2x {number} X component of control point 2
 * @param p2y {number} Y component of control point 2
 * @param x {number} the value of x along the bezier curve, 0.0 <= x <= 1.0
 * @param duration {number} the duration of the animation in milliseconds
 * @return {number} the y value along the bezier curve
 */
 cubicBezier: function(p1x, p1y, p2x, p2y, x, duration) {
 return unitBezier(p1x, p1y, p2x, p2y)(x, duration);
 }
 */
func cubicBezierJS(p1x: CGFloat,
                   p1y: CGFloat,
                   p2x: CGFloat,
                   p2y: CGFloat,
                   x: CGFloat, // progress -- how far along in TIME we are.
                   duration: CGFloat) -> CGFloat {

    unitBezierJS(p1x: p1x,
                 p1y: p1y,
                 p2x: p2x,
                 p2y: p2y)(x, duration)
}

/*
 /**
 * The epsilon value we pass to UnitBezier::solve given that the animation is going to run over |dur| seconds.
 * The longer the animation, the more precision we need in the timing function result to avoid ugly discontinuities.
 * http://svn.webkit.org/repository/webkit/trunk/Source/WebCore/page/animation/AnimationBase.cpp
 */
 var solveEpsilon = function(duration) {
 return 1.0 / (200.0 * duration);
 };
 */
func solveEpsilon(_ duration: CGFloat) -> CGFloat {
    1.0 / (200 * duration)
}

/*
 /**
 * Defines a cubic-bezier curve given the middle two control points.
 * NOTE: first and last control points are implicitly (0,0) and (1,1).
 * @param p1x {number} X component of control point 1
 * @param p1y {number} Y component of control point 1
 * @param p2x {number} X component of control point 2
 * @param p2y {number} Y component of control point 2
 */
 var unitBezier = function(p1x, p1y, p2x, p2y) {
 */

// added `x` and `duration`, to avoid returning another function
func unitBezierJS(p1x: CGFloat,
                  p1y: CGFloat,
                  p2x: CGFloat,
                  p2y: CGFloat) -> (CGFloat, CGFloat) -> CGFloat {

    let cx = 3.0 * p1x
    let bx = 3.0 * (p2x - p1x) - cx
    let ax = 1.0 - cx - bx
    let cy = 3.0 * p1y
    let by = 3.0 * (p2y - p1y) - cy
    let ay = 1.0 - cy - by

    let sampleCurveX = { (t: CGFloat) in
        // `ax t^3 + bx t^2 + cx t' expanded using Horner's rule.
        ((ax * t + bx) * t + cx) * t
    }

    let sampleCurveY = { (t: CGFloat) in
        ((ay * t + by) * t + cy) * t
    }

    let sampleCurveDerivativeX = { (t: CGFloat) in
        (3.0 * ax * t + 2.0 * bx) * t + cx
    }

    /*
     /**
     * Given an x value, find a parametric value it came from.
     * @param x {number} value of x along the bezier curve, 0.0 <= x <= 1.0
     * @param epsilon {number} accuracy limit of t for the given x
     * @return {number} the t value corresponding to x
     */
     var solveCurveX = function(x, epsilon) {
     */
    let solveCurveX = { (x: CGFloat, epsilon: CGFloat) in
        var t0: CGFloat
        var t1: CGFloat
        var t2: CGFloat
        var x2: CGFloat

        var d2: CGFloat

        //        var i: CGFloat

        // First try a few iterations of Newton's method -- normally very fast.
        //        for (t2 = x, i = 0; i < 8; i++) {
        for _t2 in (0..<9) {
            var t2 = CGFloat(_t2)
            x2 = sampleCurveX(CGFloat(t2)) - x
            if x2.abs < epsilon {
                return t2
            }
            d2 = sampleCurveDerivativeX(CGFloat(t2))
            if d2.abs < 1e-6 {
                break
            }
            t2 -= x2 / d2
        }

        // Fall back to the bisection method for reliability.
        t0 = 0.0
        t1 = 1.0
        t2 = x

        if t2 < t0 {
            log("returning t0 since t2 < t0")
            return t0
        }
        if t2 > t1 {
            log("returning t1 since t2 > t1")
            return t1
        }

        while t0 < t1 {
            x2 = sampleCurveX(t2)
            if (x2 - x).abs < epsilon {
                return t2
            }
            if x > x2 {
                t0 = t2
            } else {
                t1 = t2
            }
            t2 = (t1 - t0) * 0.5 + t0
        }

        log("returning t2 after bisection method")

        // Failure.
        return t2
    } // solveCurveX

    /*
     /**
     * @param x {number} the value of x along the bezier curve, 0.0 <= x <= 1.0
     * @param epsilon {number} the accuracy of t for the given x
     * @return {number} the y value along the bezier curve
     */
     var solve = function(x, epsilon) {
     return sampleCurveY(solveCurveX(x, epsilon));
     };
     */
    let solve = { (x: CGFloat, epsilon: CGFloat) in
        sampleCurveY(solveCurveX(x, epsilon))
    }

    /*
     /**
     * Find the y of the cubic-bezier for a given x with accuracy determined by the animation duration.
     * @param x {number} the value of x along the bezier curve, 0.0 <= x <= 1.0
     * @param duration {number} the duration of the animation in milliseconds
     * @return {number} the y value along the bezier curve
     */
     return function(x, duration) {
     return solve(x, solveEpsilon(+duration || DEFAULT_DURATION));
     };
     */
    return { (x: CGFloat, duration: CGFloat) in
        return solve(x, solveEpsilon(duration))
    }
} // unitBezierJS
