//
//  ScrollPagingInteractionHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/24/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// returns (updated current output,
//          shouldRunDimensionAgain)
func handlePaging(currentOutput: Double,
                  paging: PagingDimensionState,
                  childSize: Double,
                  parentSize: Double,
                  previousDragPosition: CGFloat?,
                  velocityAtIndex: Double,
                  pageSize: Double,
                  pagePadding: Double,
                  hadJump: Bool,
                  isDisabledScrollMode: Bool) -> ScrollModeDimensionResult {

    var result: ScrollModeDimensionResult
    let currentOutput = currentOutput
    let isPageSizeUnset = pageSize == .zero
    let pageSize = isPageSizeUnset ? parentSize : pageSize
    // previous drag position is still defined on first cycle after drag ends
    let didScrollJustEnd = previousDragPosition.isDefined
    let shouldStartPage = didScrollJustEnd && !hadJump
    let isPagingInProgress = (paging.distance != .zero && !hadJump) || shouldStartPage
    let shouldPage = shouldStartPage || isPagingInProgress
    var paging = paging

    // If we should page, then we actually completely ignore the rubberbanding.
    // (Even for run-again purposes).
    if shouldStartPage {
        guard let previousDragPosition = previousDragPosition else {
            #if DEBUG
            fatalError()
            #endif
            return .init(position: currentOutput,
                         scrollMode: .paging(paging),
                         shouldRunAgain: false)
        }
        
        paging = preparePagingDimensionState(
            parentLength: parentSize,
            childLength: childSize,
            childLocation: currentOutput,
            previousDragLocation: previousDragPosition,
            velocityAtIndex: velocityAtIndex,
            pageSize: pageSize,
            pagePadding: pagePadding)
    }
    
    if isPagingInProgress {
        let (updatedOutput,
             updatedShouldPage) = runPaging(currentOutput: currentOutput,
                                            paging: paging)
        result = .init(position: updatedOutput,
                     scrollMode: .paging(paging),
                     shouldRunAgain: updatedShouldPage)
    }

    // If we don't need to page, then run rubberbanding.
    else {
        //        log("handlePaging: might rubberband")
        let (updatedOutput,
             shouldRubberband) = runFreeRubberbanding(
                currentOutput: currentOutput,
                frame: paging.frame,
                childSize: childSize,
                parentSize: parentSize)

        result = .init(position: updatedOutput,
                     scrollMode: .paging(paging),
                     shouldRunAgain: shouldRubberband)
    }
    
    if !isDisabledScrollMode && !hadJump {
        if paging.isJumpAnimation && !result.shouldRunAgain {
            log("this paging-state was from a jump animation, and the paging part has completed")
            // This paging-state was from a jump animation,
            // and the paging part has completed,
            // but we may need to rubberband.
            result.shouldRunAgain = true
            paging.distance = 0 // so that shouldPage will be false
            paging.frame = 0 // reset to 0, since rubbberbanding is new animation
            result.scrollMode = .paging(paging)
        }
        
        if paging.isJumpAnimation && !shouldPage && !result.shouldRunAgain {
            // i.e. this paging-state was created from a jump animation,
            // and we're won't page (since !shouldPage)
            // and we're either done rubberbanding or don't need to rubberband (since !updatedShouldRunY),
            // and so we can just stop the whole animation for this axis.
            log("this paging-state was from a jump animation, and both the paging and rubberbanding parts have completed")
            result.shouldRunAgain = false
        }
    } // if !isDisabledScrollModeY
    
    return result
}

// returns (updated output, shouldPage)
func runPaging(currentOutput: CGFloat,
               paging: PagingDimensionState) -> (CGFloat, Bool) {

    // difference
    let pagingDiff = paging.end - paging.start
    
    guard pagingDiff != 0 else {
        return (currentOutput, false)
    }

    // frameTime
    let pagingFrameTime = CGFloat(paging.frame) / FREE_SCROLL_RUBBERBAND_FRAMERATE

    let pagingDifferenceByFrame = pagingDiff * pagingFrameTime

    if pagingDifferenceByFrame == 0
        || areEquivalent(n: currentOutput, n2: paging.end) {

        //        log("runPaging: at zero or equivalent; do not need to run paging again")
        return (currentOutput, true)
    } else {
        // `reduced` = eyeballed...
        let _reducedPagingDiff = pagingDifferenceByFrame / 3
        let newOutput = paging.start + _reducedPagingDiff
        let runAgain = !areEquivalent(n: newOutput, n2: paging.end)

        //        log("runPaging: _reducedPagingDiff: \(_reducedPagingDiff)")
        //        log("runPaging: newOutput: \(newOutput)")
        //        log("runPaging: paging.start: \(paging.start)")
        //        log("runPaging: paging.end: \(paging.end)")
        //        log("runPaging: runAgain: \(runAgain)")

        return (newOutput, runAgain)
    }
}
