//
//  WaveSpring.swift
//  Stitch
//
//  Created by Christian J Clampitt on 4/2/24.
//

import Foundation
import SwiftUI


struct SpringHelpers {
    
    // TODO: don't create a native Spring everytime; instead, store it on the animation state
    static func progress(spring: Spring,
                         from: CGFloat, // current output
                         to: CGFloat, // toValue
                         velocity: CGFloat) -> (CGFloat, CGFloat) {
        
        let dampingCoefficient = SpringHelpers.bandedDampingCoefficient(
            dampingRatio: spring.dampingRatio,
            response: spring.response,
            mass: spring.mass)
        
        let (newPosition, newVelocity) = SpringHelpers._progress(
            springStiffness: spring.stiffness,
            springDampingCoefficient: dampingCoefficient,
            springMass: spring.mass,
            value: from,
            target: to,
            velocity: velocity)
        
        return (newPosition, newVelocity)
    }
    
    // Note: requires WaveSpring parameters
    private static func _progress(springStiffness: CGFloat,
                                  springDampingCoefficient: CGFloat,
                                  springMass: CGFloat,
                                  value: CGFloat, // current output
                                  target: CGFloat, // toValue
                                  velocity: CGFloat) -> (value: CGFloat,
                                                         velocity: CGFloat) {
        
        // Always e.g. 0.0166667; does not change during spring's animation.
        let ASSUMED_GRAPH_STEP = SPRING_ANIMATION_STEP_SIZE
        
        let displacement = value - target
        let springForce = (-springStiffness * displacement)
        let dampingForce = (springDampingCoefficient * velocity)
        let force = springForce - dampingForce
        let acceleration = force / springMass
        
        let newVelocity = (velocity + (acceleration * ASSUMED_GRAPH_STEP))
        let newValue = (value + (newVelocity * ASSUMED_GRAPH_STEP))
        
        return (value: newValue, velocity: newVelocity)
    }
    
    private static func bandedDampingCoefficient(dampingRatio: CGFloat, response: CGFloat, mass: CGFloat) -> CGFloat {
        
        let unbandedDampingCoefficient = Self.dampingCoefficient(
           dampingRatio: dampingRatio,
           response: response,
           mass: mass)
        
        return SpringHelpers.rubberband(value: unbandedDampingCoefficient, range: 0...60, interval: 15)
    }
    
    private static func dampingCoefficient(dampingRatio: CGFloat, response: CGFloat, mass: CGFloat) -> CGFloat {
        4.0 * .pi * dampingRatio * mass / response
    }
    
    private static func rubberband(value: CGFloat, range: ClosedRange<CGFloat>, interval: CGFloat, c: CGFloat = 0.55) -> CGFloat {
        // * x = distance from the edge
        // * c = constant value, UIScrollView uses 0.55
        // * d = dimension, either width or height
        // b = (1.0 – (1.0 / ((x * c / d) + 1.0))) * d
        if range.contains(value) {
            return value
        }

        let d: CGFloat = interval

        if value > range.upperBound {
            let x = value - range.upperBound
            let b = (1.0 - (1.0 / ((x * c / d) + 1.0))) * d
            return range.upperBound + b
        } else {
            let x = range.lowerBound - value
            let b = (1.0 - (1.0 / ((x * c / d) + 1.0))) * d
            return range.lowerBound - b
        }
    }
}
