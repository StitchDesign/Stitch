//
//  ForwardEdgeHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/15/23.
//

import SwiftUI
import StitchSchemaKit

// This doesn't change for "destination below vs above"?
func halfXPoint(_ from: CGPoint,
                _ to: CGPoint,
                fromIndex: Int,
                totalOutputs: Int,
                useLegacy: Bool,
                isActivelyDragged: Bool) -> CGFloat {

    return newStyleHalfXPoint(
        from,
        to,
        fromIndex,
        totalOutputs: totalOutputs,
        isActivelyDragged: isActivelyDragged)

    //    if useLegacy {
    //        //    if useLegacy, !isActivelyDragged {
    //        return from.x + xDistance(from, to)/2
    //    } else {
    //        return newStyleHalfXPoint(
    //            from,
    //            to,
    //            fromIndex,
    //            totalOutputs: totalOutputs,
    //            isActivelyDragged: isActivelyDragged)
    //    }
}

// back-set stays the same, whether destination is above or below origin
func fromIndexBackSet(_ fromIndex: Int,
                      totalOutputs: Int) -> Int {
    let p = (fromIndex - totalOutputs)
    //    print("fromIndexBackSet: p: \(p)")
    return p
}

// Use similar strategy as from backward edge UI?
func newStyleHalfXPoint(_ from: CGPoint,
                        _ to: CGPoint,
                        _ fromIndex: Int,
                        totalOutputs: Int,
                        isActivelyDragged: Bool) -> CGFloat {

    // from the origin to half-way across the distance to the destination
    //    let distance = from.x + (xDistance(from, to)/2)

    let xGap = xDistance(from, to)

    // from the origin to half-way across the distance to the destination
    let distance = from.x + (xGap/2)

    // log("Forward Edge: newStyleHalfXPoint: from.y: \(from.y)")
    // log("Forward Edge: newStyleHalfXPoint: to.y: \(to.y)")

    // log("Forward Edge: newStyleHalfXPoint: from.x: \(from.x)")
    // log("Forward Edge: newStyleHalfXPoint: to.x: \(to.x)")

    // log("Forward Edge: newStyleHalfXPoint: fromIndex: \(fromIndex)")
    // log("Forward Edge: newStyleHalfXPoint: totalOutputs: \(totalOutputs)")

    // log("Forward Edge: newStyleHalfXPoint: xGap: \(xGap)")
    // log("Forward Edge: newStyleHalfXPoint: distance: \(distance)")

    if totalOutputs == 1 {
        // log("Forward Edge: newStyleHalfXPoint: only one output, so will return distance")
        return distance
    }

    //    return distance

    // 18? why? 12 + 6, i.e. edge width + half of space between them?
    let allEdgesShift = ((LINE_EDGE_WIDTH + LINE_EDGE_WIDTH/2) * (totalOutputs - 1).toCGFloat)

    let shiftFromTotalEdgeCount: CGFloat = totalOutputs > 1 ? allEdgesShift : 0

    //    let shiftPerEdge = CGFloat(fromIndex * 24)
    let shiftPerEdge = CGFloat(fromIndex * 24)

    // log("Forward Edge: newStyleHalfXPoint: shiftPerEdge: \(shiftPerEdge)")
    // log("Forward Edge: newStyleHalfXPoint: shiftFromTotalEdgeCount: \(shiftFromTotalEdgeCount)")

    var belowMidX = distance
        - shiftPerEdge.magnitude
        + shiftFromTotalEdgeCount

    var aboveMidX = distance
        + shiftPerEdge.magnitude
        - shiftFromTotalEdgeCount.magnitude

    // log("Forward Edge: newStyleHalfXPoint: belowMidX: \(belowMidX)")
    // log("Forward Edge: newStyleHalfXPoint: aboveMidX: \(aboveMidX)")

    // the mid point must be at least +20 points ahead of from.x
    //    let minMidXFrom = from.x + 20
    let minMidXFrom = from.x + (isActivelyDragged ? 8 : 20)

    // log("Forward Edge: newStyleHalfXPoint: minMidXFrom: \(minMidXFrom)")

    // the mid point must be at least -20 points behind to.x
    //    let minMidXTo = to.x - 20
    let minMidXTo = to.x - (isActivelyDragged ? 8 : 20)

    // log("Forward Edge: newStyleHalfXPoint: minMidXTo: \(minMidXTo)")

    if belowMidX < minMidXFrom {
        // log("Forward Edge: set belowMidX to minMidXFrom")
        belowMidX = minMidXFrom
    }
    if aboveMidX < minMidXFrom {
        // log("Forward Edge: set aboveMidX to minMidXFrom")
        aboveMidX = minMidXFrom
    }

    if belowMidX > minMidXTo {
        // log("Forward Edge: set belowMidX to minMidXTo")
        belowMidX = minMidXTo
    }
    if aboveMidX > minMidXTo {
        // log("Forward Edge: set aboveMidX to minMidXTo")
        aboveMidX = minMidXTo
    }

    // ALSO NEED TO CHECK WHETHER MIN MID X IS 20 POINTS WEST OF TO.X

    // WHAT HAPPENS IF BOTH FROM.X IS AND TO.X NEED

    // the mid point must be at least 20 (16?) points ahead of From.X
    // and at least 20 (16?) points behind To.x

    // If destination is below, the first edge's mid x point has to be moved forward (+x)
    if destinationIsBelow(from, to) {

        //        if belowMidX < from.x {
        //        if belowMidX <= from.x {
        //            //            return from.x // mid point of a forward edge can never be east of port
        //                    log("Forward Edge: destination below: newStyleHalfXPoint: was flush")
        //            return from.x // + 8 // mid point of a forward edge can never be east of port
        //        }

        let activeDragSmallerMidX = from.x + xGap
        // log("Forward Edge: destination below: activeDragSmallerMidX: \(activeDragSmallerMidX)")

        if isActivelyDragged,
           activeDragSmallerMidX < aboveMidX {
            // log("Forward Edge: destination below: newStyleHalfXPoint: will use activeDragSmallerMidX: \(activeDragSmallerMidX)")
            return activeDragSmallerMidX
        }

        return belowMidX
    }

    // If the destination is above, the first edge's mid x point has to be moved back (-x)
    else {

        //        if aboveMidX < from.x {
        //            //            return from.x // mid point of a forward edge can never be east of port
        //                    log("Forward Edge: destination below: newStyleHalfXPoint: was flush")
        //            return from.x // + 8 // mid point of a forward edge can never be east of port
        //        }

        let activeDragSmallerMidX = from.x + xGap
        // log("Forward Edge: destination above: activeDragSmallerMidX: \(activeDragSmallerMidX)")

        if isActivelyDragged,
           activeDragSmallerMidX < aboveMidX {
            // log("Forward Edge: destination above: newStyleHalfXPoint: will use activeDragSmallerMidX: \(activeDragSmallerMidX)")
            return activeDragSmallerMidX
        }

        return aboveMidX
    }
}
