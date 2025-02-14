//
//  SpringAnimationNumberOp.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/29/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// NOTE: Used by both pop and spring animation nodes.
func springAnimationNumberOp(values: PortValues, // ie inputs and outputs
                             computedState: ComputedNodeState,
                             graphTime: TimeInterval,
                             isPopAnimation: Bool) -> ImpureEvalOpResult {
        
    //    log("springAnimationNumberOp: eval called")
    //    log("springAnimationNumberOp: isPopAnimation: \(isPopAnimation)")
        
    let animationState = computedState.springAnimationState ?? .one(.init())
    
    // Coerce animation state to single type
    var singleAnimationState: OneFieldSpringAnimation
    switch animationState {
    case .one(let _singleAnimationState):
        singleAnimationState = _singleAnimationState
    default:
        singleAnimationState = OneFieldSpringAnimation(values: .init())
    }
    
    // the goal number
    let toValue: Double = values.first?.getNumber ?? .zero
    
    
    // Pop node has 3 inputs, so the current output will be the 4th value, i.e. index = 3
    // Spring node has 4 inputs, so current output will be 5th value, i.e. index = 4
    let currentOutputIndex = isPopAnimation ? 3 : 4
    
    // i.e. current output
    let position: Double = graphTime.graphJustStarted ? toValue : values[safe: currentOutputIndex]?.getNumber ?? toValue
    
    //    log("springAnimationNumberOp: position: \(position)")
    //    log("springAnimationNumberOp: toValue: \(toValue)")
    
    var mass: Double
    var damping: Double
    var stiffness: Double
    
    if isPopAnimation {
        let bounciness = values[safe: 1]?.getNumber ?? .zero
        let speed = values[safe: 2]?.getNumber ?? .zero
        
        let (derivedDamping, derivedStiffness) = convertBouncinessAndSpeedToFrictionAndTension(
            bounciness: bounciness,
            speed: speed)
        
        // Round the damping and stiffness we received from converting the Bounciness and Speed inputs on the Pop Animation node,
        // since we can get e.g. a single digit difference in the 8th place etc.,
        // which makes us think the parameters have changed.
        mass = 1 // TODO: what mass to actually use?
        damping = Int(derivedDamping).toDouble // .rounded(toPlaces: 3)
        stiffness = Int(derivedStiffness).toDouble // .rounded(toPlaces: 3)
    } else {
        mass = values[1].getNumber!
        stiffness = values[safe: 2]?.getNumber ?? .zero
        damping = values[safe: 3]?.getNumber ?? .zero
    }
        
    // log("springAnimationNumber: mass: \(mass)")
    // log("springAnimationNumber: damping: \(damping)")
    // log("springAnimationNumber: stiffness: \(stiffness)")
    
    let roundedPosition = position.rounded(toPlaces: 5)
    let roundedToValue = toValue.rounded(toPlaces: 5)
    
    let smallVelocity: Bool = singleAnimationState.values.springValues.map({
        $0.currentVelocity <= SPRING_ANIMATION_VELOCITY_EPSILON
    }) ?? false
    let nearDestination = roundedPosition == roundedToValue
    let normalStoppingPoint = smallVelocity && nearDestination
    
    let zeroParamsStoppingPoint = !isPopAnimation && stiffness == .zero && damping == .zero
    
    
//    // If we have small velocity (i.e. less LTE some epsilon),
//    // and we're close to our goal,
//    // then the animation is done.
    if zeroParamsStoppingPoint || normalStoppingPoint {
        
        //        log("springAnimationNumberOp: DONE ANIMATING")
        //        log("springAnimationNumberOp: velocity: \(velocity)")
        //        log("springAnimationNumberOp: roundedPosition: \(roundedPosition)")
        //        log("springAnimationNumberOp: roundedToValue: \(roundedToValue)")
        //        log("springAnimationNumberOp: toValue: \(toValue)")
        
        // wipe animation values
        singleAnimationState.values.springValues = nil
        computedState.springAnimationState = .one(singleAnimationState)
        
        return .init(outputs: [.number(toValue)],
                     willRunAgain: false)
    }
    
    // i.e. Do we need to initialize the animation?
    guard var springValues = singleAnimationState.values.springValues else {
        
        //        log("springAnimationNumberOp: will initialize springValues")
        
        // Use SwiftUI native Spring to model damping, stiffness etc.
        let spring = Spring(mass: mass,
                            stiffness: stiffness,
                            damping: damping)
        
        singleAnimationState.values.springValues = .init(
            spring: spring,
            // When an animation starts,
            // we animate from the current output (fromValue),
            // to the goal (toValue)
            fromValue: position,
            toValue: toValue)
        
        computedState.springAnimationState = .one(singleAnimationState)
        
        // Exit from eval, but indicate that node should run again
        // TODO: this will exit before we've run the animation at stepTime=0; is that okay? stepTime=0 always returns the `fromValue`?
        return .init(outputs: [.number(position)],
                     willRunAgain: true)
    }
    
    // log("springAnimationNumber: springValues.spring.mass: \(springValues.spring.mass)")
    // log("springAnimationNumber: springValues.spring.damping: \(springValues.spring.damping)")
    // log("springAnimationNumber: springValues.spring.stiffness: \(springValues.spring.stiffness)")
    
    // TODO: revisit this?: retargeting actually seems unnecessary in the case of RepeatingAnimation + Pop ? What about Humane / Drag?
//    // We changed toValue during an animation, i.e. retargeting
    if springValues.toValue != toValue {
        //         log("springAnimationNumberOp: retargeted")
        
        // The new fromValue is our current output
        springValues.fromValue = position
        
        // Update springValues toValue
        springValues.toValue = toValue
        
        // Reset animation progress: step-time and velocity
        springValues.stepTime = .zero
        // springValues.currentVelocity = .zero // maybe doesn't need to be reset?
        
        // Put updated springValues back in animationState
        singleAnimationState.values.springValues = springValues
        computedState.springAnimationState = .one(singleAnimationState)
        
        // Note: retargeting requires resetting "runtime so far" and velocity, but otherwise animation step can continue on as expected. DO NOT return early.
        //        return .init(outputs: [.number(position)],
        //                     willRunAgain: true)
        
    }
        
    // TODO: the node's inputs (spring node = mass, damping, stiffness; pop node = bounciness, speed) should be saved on animation state, and parameters are only considered to have changed when the node's current inputs do not match what was saved in animation state
    let massChanged = Int(springValues.spring.mass) != Int(mass)
    let dampingChanged = Int(springValues.spring.damping) != Int(damping)
    let stiffnessChanged = Int(springValues.spring.stiffness) != Int(stiffness)
    let parametersChanged = massChanged || dampingChanged || stiffnessChanged
                           
    if parametersChanged {
        // log("springAnimationNumberOp: parameters changed")
        
        let newSpring = Spring(mass: mass,
                               stiffness: stiffness,
                               damping: damping)
        
        springValues.spring = newSpring
        
        // current position becomes new fromValue
        // Note: toValue does not change
        springValues.fromValue = position
        
        // Maybe?: Velocity does not need to be reset?
        springValues.stepTime = .zero
        springValues.currentVelocity = .zero
        
        // Put updated springValues back in animationState
        singleAnimationState.values.springValues = springValues
        computedState.springAnimationState = .one(singleAnimationState)
        
        // Note: current output does not automatically change just because mass, stiffness or damping changed;
        // we'll need to run
        return .init(outputs: [.number(position)],
                     willRunAgain: true)
    }
    
    // i.e. Regular run of animation
    
    // Increment the animation step time
    
    // TODO: properly handle 60 vs 120 FPS by detecting average graph speed;
    // For now we assume Catalyst is 60 FPS and iOS is 120 FPS,
    // e.g. MacBook Air is 60 FPS, but some iPhones and iPads are 120 FPS
    springValues.stepTime += SPRING_ANIMATION_STEP_SIZE
    
    //    log("springAnimationNumberOp: springValues.stepTime: \(springValues.stepTime)")
    //    log("springAnimationNumberOp: springValues.fromValue: \(springValues.fromValue)")
    //    log("springAnimationNumberOp: toValue: \(toValue)")
    
    let (newPosition, newVelocity) = SpringHelpers.progress(
        spring: springValues.spring,
        from: position,
        to: toValue,
        velocity: springValues.currentVelocity)
                
    // Set new velocity
    springValues.currentVelocity = newVelocity
    singleAnimationState.values.springValues = springValues
    computedState.springAnimationState = .one(singleAnimationState)
    
    // log("springAnimationNumber: newPosition: \(newPosition)")
    
    return .init(outputs: [.number(newPosition)],
                 willRunAgain: true)
}
