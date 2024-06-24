//
//  ScrollInteractionHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/24/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Helpers for scroll interaction node eval

// returns (updated current output,
//          updated free state,
//          shouldRunDimensionAgain)
func handleScrollFree(currentOutput: Double,
                      free: FreeScrollDimensionMomentum,
                      childSize: CGFloat,
                      parentSize: CGFloat) -> ScrollModeDimensionResult {

    var free = free
    var currentOutput = currentOutput

    // FREE: MOMENTUM
    if free.shouldRun {
        //        log("handleScrollFree: shouldRun")
        let (updatedFree, momentAdjustment) = runFreeMomentum(free)
        free = updatedFree
        currentOutput += momentAdjustment
    } // if shouldRunMomentum

    // FREE: RUBBERBANDING
    let (updatedOutput,
         shouldRubberband) = runFreeRubberbanding(currentOutput: currentOutput,
                                                  frame: free.frame,
                                                  childSize: childSize,
                                                  parentSize: parentSize)
    //    log("handleScrollFree: updatedOutput: \(updatedOutput)")
    currentOutput = updatedOutput

    if !shouldRubberband && !free.shouldRun {
        //        log("handleScrollFree: did not need to rubberband nor do momentum")
        return .init(position: currentOutput,
                     scrollMode: .free(FreeScrollDimensionMomentum()),
                     shouldRunAgain: false)
    } else {
        //        log("handleScrollFree: needed to rubberband or do momentum")
        return .init(position: currentOutput,
                     scrollMode: .free(free),
                     shouldRunAgain: true)
    }
}

// returns (updated free state, momentum adjustment)
func runFreeMomentum(_ free: FreeScrollDimensionMomentum) -> (FreeScrollDimensionMomentum, CGFloat) {

    var free = free

    let (updatedMomentum,
         momentumYAdjustment) = freeScrollDimensionMomentumOp(free)

    free = updatedMomentum
    //    log("runFreeMomentum: momentumYAdjustment: \(momentumYAdjustment)")
    //    log("runFreeMomentum: free after momentumYAdjustment is: \(free)")

    let metTotalStepRequirement = CGFloat(free.frame) > FREE_SCROLL_MOMENTUM_END_STEP_COUNT
    let numberTooSmall = momentumYAdjustment.magnitude < 0.1
    //
    //    log("runFreeMomentum: shouldRunMomentumY: metTotalStepRequirement: \(metTotalStepRequirement)")
    //    log("runFreeMomentum: shouldRunMomentumY: numberTooSmall: \(numberTooSmall)")

    if metTotalStepRequirement || numberTooSmall {
        //        log("runFreeMomentum: setting y free.shouldRun false")
        free.shouldRun = false
    }

    return (free, momentumYAdjustment)
}

// returns (new value for current output along that dimension,
//          shouldRubberband up/down/left/right)
func runFreeRubberbanding(currentOutput: CGFloat,
                          frame: CGFloat,
                          childSize: CGFloat,
                          parentSize: CGFloat) -> (CGFloat, Bool) {

    let rubberbandingDirection = calcRubberBandingDirection(
        childSize: childSize,
        childPosition: currentOutput,
        parentSize: parentSize)

    //    log("runFreeRubberbanding: rubberbandingDirection: \(rubberbandingDirection)")

    let rubberbandingDestination = getRubberBandingEndPosition(
        parentSize: parentSize,
        childSize: childSize,
        childPosition: currentOutput,
        rubberBanding: rubberbandingDirection)

    //    log("runFreeRubberbanding: rubberbandingDestination: \(rubberbandingDestination)")

    // neg for y axis = moving up
    // neg for x axis = moving left
    let shouldRubberbandNeg = rubberbandingDirection == .neg

    // pos for y axis = moving down
    // pos for x axis = moving right
    let shouldRubberbandPos = rubberbandingDirection == .pos

    let shouldRubberband = shouldRubberbandNeg || shouldRubberbandPos

    //    log("runFreeRubberbanding: shouldRubberbandUp: \(shouldRubberbandNeg)")
    //    log("runFreeRubberbanding: shouldRubberbandDown: \(shouldRubberbandPos)")

    guard shouldRubberband else {
        //        log("runFreeRubberbanding: did not need to rubberband")
        return (currentOutput, shouldRubberband)
    }

    // end - start
    // `start` is always the child's current position, ie currentOutput
    let rubberbandingDiff = rubberbandingDestination - currentOutput
    //    log("runFreeRubberbanding: rubberbandingDiff: \(rubberbandingDiff)")

    let frameTime = CGFloat(frame) / FREE_SCROLL_RUBBERBAND_FRAMERATE
    //    log("runFreeRubberbanding: frameTime: \(frameTime)")

    let differenceForFrameTime = rubberbandingDiff * frameTime
    //    log("runFreeRubberbanding: differenceForFrameTime: \(differenceForFrameTime)")

    let reducedDiff = differenceForFrameTime / 3
    //    log("runFreeRubberbanding: reducedDiff: \(reducedDiff)")

    let newOutput = currentOutput + reducedDiff
    //    log("runFreeRubberbanding: newOutput: \(newOutput)")

    let overshot = shouldRubberbandNeg && newOutput < rubberbandingDestination
    let undershot = shouldRubberbandPos && newOutput > rubberbandingDestination

    //    log("runFreeRubberbanding: overshot: \(overshot)")
    //    log("runFreeRubberbanding: undershot: \(undershot)")

    // THIS SEEMS STRANGE, IF WE'VE OVERSHOT
    if overshot || undershot {
        return (rubberbandingDestination, shouldRubberband)
    } else {
        return (newOutput, shouldRubberband)
    }
}
