//
//  GridLinesHelper.swift
//  prototype
//
//  Created by Christian J Clampitt on 5/9/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO: consider eg a higher minimum for perf/rendering,
// eg 0.4 or 0.5
let GRID_SCALE_MINIMUM: CGFloat = 0.3

let SQUARE_SIDE_LENGTH = 25 // previously: 50

/*
 Determine the new resting position of a moved node,
 based on how node's top and left sides should line up
 with a y-axis grid line and an x-axis grid line.
 */
func determineSnapPosition(position: CGPoint,
                           previousPosition: CGPoint,
                           nodeSize: CGSize,
                           gridSquareLength: Int = SQUARE_SIDE_LENGTH) -> CGPoint {

    //    log("determineSnapPosition: position: \(position)")
    //    log("determineSnapPosition: previousPosition: \(previousPosition)")
    //    log("determineSnapPosition: nodeSize: \(nodeSize)")

    let height = nodeSize.height
    let width = nodeSize.width

    let yDiff = position.y - previousPosition.y
    let xDiff = position.x - previousPosition.x

    //    log("determineSnapPosition: yDiff: \(yDiff)")
    //    log("determineSnapPosition: xDiff: \(xDiff)")

    // this threshold doesn't work for the square size?
    let threshold = CGFloat(gridSquareLength/2)
    //    log("determineSnapPosition: nodeSize: \(nodeSize)")

    // Moving left = -x
    let movedLeft = xDiff < 0 //  end.x < start.x
    let movedRight = xDiff > 0 // end.x > start.x

    // Moving up = -y
    let movedUp = yDiff < 0 // end.y < start.y
    let movedDown = yDiff > 0 // end.y > start.y

    let movedYEnough = abs(yDiff) >= threshold
    let movedXEnough = abs(xDiff) >= threshold

    // If we didn't move it enough (regardless of direction),
    // then just snap back to original (previous) position
    if !movedYEnough && !movedXEnough {
        //        log("determineSnapPosition: Will snap back")
        return previousPosition
    }

    // If we did move enough, then x and/or y will be updated:
    var newY = position.y
    var newX = position.x

    if movedYEnough {

        //        log("determineSnapPosition: movedYEnough")

        // When determining which line to snap to,
        // factor out the distance we had displaced the node's center
        // for visual grid alignment.
        let yAdjustment = yPositionAdjustment(height)
        let adjustedHeight = position.y - yAdjustment // yPositionAdjustment(height)

        //        log("determineSnapPosition: yAdjustment: \(yAdjustment)")
        //        log("determineSnapPosition: adjustedHeight: \(adjustedHeight)")

        let (prevMultiple, nextMultiple) = getMultiples(adjustedHeight,
                                                        gridSquareLength)

        //        log("determineSnapPosition: prevMultiple: \(prevMultiple)")
        //        log("determineSnapPosition: nextMultiple: \(nextMultiple)")

        // distance between current position and next grid line to the top
        let topDistance = abs(adjustedHeight - prevMultiple)
        let bottomDistance = abs(adjustedHeight - nextMultiple)

        //        log("determineSnapPosition: topDistance: \(topDistance)")
        //        log("determineSnapPosition: bottomDistance: \(bottomDistance)")

        // if topDistance is smaller,
        // then move to the top grid line.
        if topDistance < bottomDistance {
            // it's 'prev' because moving toward top is NEGATIVE y,
            // ie SMALLER y
            newY = prevMultiple
        } else if bottomDistance < topDistance {
            newY = nextMultiple
        } else if bottomDistance == topDistance {
            // this is a case where prev == next, actually;
            // and so we can just pick one distance;
            // otherwise we end up not adjusting the position
            newY = nextMultiple
        }

        //        log("determineSnapPosition: newY after a multiple: \(newY)")

        // Add back the grid-alignment adjustment of the node's center.
        newY += yAdjustment // yPositionAdjustment(height)

        //        log("determineSnapPosition: newY after adding back yAdjustment: \(newY)")

        // if we didn't move x enough,
        // then we'll snap back to which line we moved away from.
        if !movedXEnough {
            //            log("determineSnapPosition: movedYEnough but not x enough")
            // if moved rightward, but not enough,
            // then need to move node leftward
            if movedRight {
                //                log("determineSnapPosition: movedXEnough but not y enough: movedRight: newX was: \(newX)")
                newX -= abs(xDiff)
                //                log("determineSnapPosition: movedXEnough but not y enough: movedRight: newX is now: \(newX)")
            } else if movedLeft {
                //                log("determineSnapPosition: movedXEnough but not y enough: movedRight ELSE: newX was: \(newX)")
                newX += abs(xDiff)
                //                log("determineSnapPosition: movedXEnough but not y enough: movedRight ELSE: newX is now: \(newX)")
            }
            //            else {
            ////                log("determineSnapPosition: movedXEnough but not y enough: moved neither left nor right...")
            //            }
        }
    }

    // NOTE: Currently all nodes' widths are multiples of grid square length * 2).
    // If that changes in the future,
    // we can also add some leftward displacement of the node's center.
    if movedXEnough {

        //        log("determineSnapPosition: movedXEnough")

        let adjustedWidth = position.x - xPositionAdjustment(width)

        let (prevMultiple, nextMultiple) = getMultiples(adjustedWidth, gridSquareLength)

        // distance between current position and next grid line to the left
        let leftDistance = abs(adjustedWidth - prevMultiple)
        let rightDistance = abs(adjustedWidth - nextMultiple)

        // if leftDistance is smaller,
        // then move to the left grid line.
        if leftDistance < rightDistance {
            newX = prevMultiple
        } else if rightDistance < leftDistance {
            newX = nextMultiple
        } else if leftDistance == rightDistance {
            // If left == right, then prev == next,
            // so just assign a multiple.
            newX = nextMultiple
        }

        //        log("determineSnapPosition: newX after a multiple: \(newY)")

        // Add back the grid-alignment adjustment of the node's center.
        newX += xPositionAdjustment(width)
        //        log("determineSnapPosition: newX after adjustment: \(newX)")

        if !movedYEnough {
            //            log("determineSnapPosition: movedXEnough but not y enough")

            // if moved down, but not enough,
            // then need to snap node back upward
            if movedDown {
                //                log("determineSnapPosition: movedXEnough but not y enough: movedDown: newY was: \(newY)")
                newY -= abs(yDiff)
                //                log("determineSnapPosition: movedXEnough but not y enough: movedDown: newY is now: \(newY)")
            } else if movedUp {
                //                log("determineSnapPosition: movedXEnough but not y enough: movedUp: newY was: \(newY)")
                newY += abs(yDiff)
                //                log("determineSnapPosition: movedXEnough but not y enough: movedUp: newY is now: \(newY)")
            }
            //            else {
            ////                log("determineSnapPosition: movedXEnough but not y enough: moved neither up nor down")
            //            }
        }
    }

    // if we had moved enough in at least one direction...
    if movedXEnough || movedYEnough {
        let finalPosition = CGPoint(x: newX,
                                    y: newY)
        //        log("determineSnapPosition: We moved enough, so will return new final position: \(finalPosition)")
        return finalPosition
    } else {
        //        log("determineSnapPosition: Will not change position")
        return position
    }
}

/*
 Get a node position that aligns node's top-left edges
 with a grid line corner.
 */
func gridAlignedPosition(center: CGPoint,
                         nodeSize: CGSize,
                         gridSquareLength: Int = SQUARE_SIDE_LENGTH) -> CGPoint {

    let height = nodeSize.height
    let adjustedHeight = center.y - yPositionAdjustment(height)
    let (prevMultipleY, _) = getMultiples(adjustedHeight, gridSquareLength)

    let width = nodeSize.width
    let adjustedWidth = center.x - xPositionAdjustment(width)
    let (prevMultipleX, _) = getMultiples(adjustedWidth, gridSquareLength)

    //    log("gridAlignedPosition: newX: \(newX)")
    //    log("gridAlignedPosition: newY: \(newY)")

    return CGPoint(
        x: prevMultipleX + xPositionAdjustment(width),
        y: prevMultipleY + yPositionAdjustment(height))
}

// return (multiple of m below n, multiple of m above n)
// eg n = 245, and m = 50, then we return (200, 250)
func getMultiples(_ n: CGFloat,
                  _ m: Int = SQUARE_SIDE_LENGTH) -> (CGFloat, CGFloat) {

    //    log("getMultiples: n was: \(n)")
    let n = Int(n)
    //    log("getMultiples: Int(n) was: \(Int(n))")
    let nextMultiple = n.roundedUp(toMultipleOf: m)
    let prevMultiple = n.roundedDown(toMultipleOf: m)
    //    log("getMultiples: nextMultiple: \(nextMultiple)")
    //    log("getMultiples: prevMultiple: \(prevMultiple)")
    return (CGFloat(prevMultiple), CGFloat(nextMultiple))
}

// We move the node's center slightly downward (based on node's size height),
// to guarantee that node's top border aligns with some grid line.
func yPositionAdjustment(_ nodeSizeHeight: CGFloat,
                         squareSideLength: Int = SQUARE_SIDE_LENGTH) -> CGFloat {

    // A node only fully covers grid squares if its
    // remainder by (grid square length * 2) == 0
    let remainder = abs(nodeSizeHeight.truncatingRemainder(dividingBy: CGFloat(squareSideLength * 2)))

    if remainder > 0 {
        // We always move the node's center DOWN,
        // hence we return a positive number.
        return remainder/2
    }
    return 0.0
}

func xPositionAdjustment(_ nodeSizeWidth: CGFloat,
                         squareSideLength: Int = SQUARE_SIDE_LENGTH) -> CGFloat {

    // A node only fully covers grid squares if its
    // remainder by (grid square length * 2) == 0
    let remainder = abs(nodeSizeWidth.truncatingRemainder(dividingBy: CGFloat(squareSideLength * 2)))

    if remainder > 0 {
        // We always move the node's center DOWN,
        // hence we return a positive number.
        return remainder/2
    }
    return 0.0
}
