//
//  SpringAnimationPositionOp.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/29/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

func springAnimationPositionOp(values: PortValues, // ie inputs and outputs
                               computedState: ComputedNodeState,
                               graphTime: TimeInterval,
                               isPopAnimation: Bool) -> ImpureEvalOpResult {
    
    //    log("springAnimationPositionOp: isPopAnimation: \(isPopAnimation)")
    let animationState = computedState.springAnimationState ?? .two(.init())
    
    // Coerce animation state to double type
    var doubleAnimationState: TwoFieldSpringAnimation
    switch animationState {
    case .two(let double):
        doubleAnimationState = double
    default:
        doubleAnimationState = .init()
    }
    
    // the goal number
    let toValue: StitchPosition = values.first?.getPosition ?? .zero
    let toValueX = toValue.x
    let toValueY = toValue.y
    
    // Pop node has 3 inputs, so the current output will be the 4th value, i.e. index = 3
    // Spring node has 4 inputs, so current output will be 5th value, i.e. index = 4
    let currentOutputIndex = isPopAnimation ? 3 : 4
    
    let currentOutput: StitchPosition = graphTime.graphJustStarted ? toValue : values[safe: currentOutputIndex]?.getPosition ?? toValue
    let currentOutputX = currentOutput.x
    let currentOutputY = currentOutput.y
    
    let velocityX = doubleAnimationState.valuesX.springValues?.currentVelocity ?? .zero
    let velocityY = doubleAnimationState.valuesY.springValues?.currentVelocity ?? .zero
    
    let hasSmallVelocityX: Bool = abs(velocityX) <= SPRING_ANIMATION_VELOCITY_EPSILON
    let hasSmallVelocityY: Bool = abs(velocityY) <= SPRING_ANIMATION_VELOCITY_EPSILON
    
    // We are done on a given dimension when goal == output AND we have small velocity
    let doneX = currentOutputX.isEquivalentTo(toValueX) && hasSmallVelocityX
    let doneY = currentOutputY.isEquivalentTo(toValueY) && hasSmallVelocityY
    
    let done = doneX && doneY
    
    if done {
        //        log("popAnimationPositionOp: done")
        computedState.springAnimationState = .two(.init())
        
        return .init(
            outputs: [.position(currentOutput)],
            willRunAgain: false
        )
    }
    
    // All spring-like animations need friction and tension,
    // but how we determine these from node's inputs
    // varies by pop animation node's inputs vs. spring's:
    var mass: Double
    var damping: Double
    var stiffness: Double
    
    if isPopAnimation {
        let bounciness = values[safe: 1]?.getNumber ?? .zero
        let speed = values[safe: 2]?.getNumber ?? .zero
        let (derivedDamping, derivedStiffness) = convertBouncinessAndSpeedToFrictionAndTension(
            bounciness: bounciness,
            speed: speed)
        mass = 1
        damping = derivedDamping.rounded(toPlaces: 5)
        stiffness = derivedStiffness.rounded(toPlaces: 5)
    } else {
        mass = values[safe: 1]?.getNumber ?? .zero
        stiffness = values[safe: 2]?.getNumber ?? .zero
        damping = values[safe: 3]?.getNumber ?? .zero
    }
    
    let zeroParamsStoppingPoint = !isPopAnimation && stiffness == .zero && damping == .zero
    
    // Same as being done
    if zeroParamsStoppingPoint {
        computedState.springAnimationState = .two(.init())
        return .init(outputs: [.position(currentOutput)],
                     willRunAgain: false)
    }
    
    
    // Do we need to initialize the x animation state?
    if doubleAnimationState.valuesX.springValues == nil {
        
        // log("springAnimationPositionOp: initialized valuesX state")
        
        let spring = Spring(mass: mass,
                            stiffness: stiffness,
                            damping: damping)
        
        doubleAnimationState.valuesX.springValues = .init(
            spring: spring,
            // When an animation starts,
            // we animate from the current output (fromValue),
            // to the goal (toValue)
            fromValue: currentOutputX,
            toValue: toValueX)
    }
    
    // Do we need to initialize the y animation state?
    if doubleAnimationState.valuesY.springValues == nil {
        
        // log("springAnimationPositionOp: initialized valuesY state")
        
        let spring = Spring(mass: mass,
                            stiffness: stiffness,
                            damping: damping)
        
        doubleAnimationState.valuesY.springValues = .init(
            spring: spring,
            // When an animation starts,
            // we animate from the current output (fromValue),
            // to the goal (toValue)
            fromValue: currentOutputY,
            toValue: toValueY)
    }
    
    var newPosition = currentOutput
    

    if  doubleAnimationState.valuesX.springValues!.toValue != toValueX {
        
        // The new fromValue is our current output
        doubleAnimationState.valuesX.springValues?.fromValue = currentOutputX
        
        // Update springValues toValue
        doubleAnimationState.valuesX.springValues?.toValue = toValueX
        
        // Reset animation progress: step-time
        doubleAnimationState.valuesX.springValues?.stepTime = .zero
    }
    
    if  doubleAnimationState.valuesY.springValues!.toValue != toValueY {
        
        // The new fromValue is our current output
        doubleAnimationState.valuesY.springValues?.fromValue = currentOutputY
        
        // Update springValues toValue
        doubleAnimationState.valuesY.springValues?.toValue = toValueY
        
        // Reset animation progress: step-time
        doubleAnimationState.valuesY.springValues?.stepTime = .zero
    }

    // TODO: add logic for "paramater changed"; see `springAnimationNumberOp`
    
    if !doneX {
        // log("springAnimationPositionOp: calculating x")
        
        doubleAnimationState.valuesX.springValues?.stepTime += SPRING_ANIMATION_STEP_SIZE
        
        guard let springValueX = doubleAnimationState.valuesX.springValues else {
            computedState.springAnimationState = .two(doubleAnimationState)
            return .init(outputs: [.position(newPosition)],
                         willRunAgain: false)
        }

        let (progressX, newVelocity) = SpringHelpers.progress(
            spring: doubleAnimationState.valuesX.springValues!.spring,
            from: currentOutputX,
            to: toValueX,
            velocity: springValueX.currentVelocity)
        
        doubleAnimationState.valuesX.springValues?.currentVelocity = newVelocity
        
        let newPositionX = progressX
        newPosition.x = newPositionX
    }
    
    if !doneY {
        // log("springAnimationPositionOp: calculating y")
        doubleAnimationState.valuesY.springValues?.stepTime += SPRING_ANIMATION_STEP_SIZE
        
        guard let springValuesY = doubleAnimationState.valuesY.springValues else {
            computedState.springAnimationState = .two(doubleAnimationState)
            return .init(outputs: [.position(newPosition)],
                         willRunAgain: false)
        }
        
        // y progress at this timestep
        let (progressY, newVelocity) = SpringHelpers.progress(
            spring: doubleAnimationState.valuesY.springValues!.spring,
            from: currentOutputY,
            to: toValueY,
            velocity: springValuesY.currentVelocity)
        
        doubleAnimationState.valuesY.springValues?.currentVelocity = newVelocity
        
        let newPositionY = progressY
        newPosition.y = newPositionY
    }
    
    // log("springAnimationPositionOp: newPosition \(newPosition); will run again")
    
    computedState.springAnimationState = .two(doubleAnimationState)
    return .init(outputs: [.position(newPosition)],
                 willRunAgain: true)
}

