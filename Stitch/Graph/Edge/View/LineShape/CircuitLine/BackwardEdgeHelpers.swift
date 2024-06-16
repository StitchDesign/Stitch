//
//  BackwardEdgeHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/15/23.
//

import SwiftUI
import StitchSchemaKit

func halfYPoint(_ from: CGPoint,
                _ to: CGPoint,
                fromIndex: Int,
                firstFrom: CGPoint,
                firstTo: CGPoint,
                lastFrom: CGPoint,
                totalOutputs: Int,
                useLegacy: Bool,
                largestYDistance: CGFloat) -> CGFloat {

    let destinationBelow = destinationIsBelow(from, to)

    if useLegacy {
        if destinationBelow {
            return from.y + yDistance(from, to)/2
        } else {
            return from.y - yDistance(from, to)/2
        }
    } else {
        return newStyleHalfYPoint(from,
                                  to,
                                  fromIndex: fromIndex,
                                  totalOutputs: totalOutputs,
                                  largestYDistance: largestYDistance)
    }

    //    let legacy = useLegacy

    //    let newStyleHalfYPoint = newStyleHalfYPoint(from,
    //                                                to,
    //                                                fromIndex: fromIndex,
    //                                                totalOutputs: totalOutputs,
    //                                                largestYDistance: largestYDistance)
    //
    //    if destinationIsBelow(from, to) {
    //        if legacy {
    //            return from.y + yDistance(from, to)/2
    //        } else {
    //            return newStyleHalfYPoint
    //        }
    //    } else {
    //        if legacy {
    //            return from.y - yDistance(from, to)/2
    //        } else {
    //            return newStyleHalfYPoint
    //        }
    //    }
}

func newStyleHalfYPoint(_ from: CGPoint,
                        _ to: CGPoint,
                        fromIndex: Int,
                        // actually the number of edges going out from this edge?
                        totalOutputs: Int,
                        largestYDistance: CGFloat) -> CGFloat {

    // log("newStyleHalfYPoint: fromIndex: \(fromIndex)")
    // log("newStyleHalfYPoint: totalOutputs: \(totalOutputs)")

    let distance = largestYDistance // yDistance(from, to)

    let destinationBelow = destinationIsBelow(from, to)

    // TODO: take into account node title height, and how many outputs the node has either below or above the output from which this edge extends
    // Note: we currently

    //    if totalOutputs == 1 {
    //        let yGap = yDistance(from, to)
    //        if destinationBelow {
    //            return from.y + (yGap/2)
    //        } else {
    //            return from.y - (yGap/2)
    //        }
    //    }

    // Each edge's y split point gets shifted (down, +y) individually
    let shiftPerEdge = indexRise(fromIndex, totalOutputs: totalOutputs)

    // Every edge's y split point shifts according to the total number of edges;
    // same for all edges.
    // Note: for a single edge, the y split point is exactly half way between the from.y and the to.y.
    let shiftFromTotalEdgeCount = totalOutputs > 1 ? (24 * (totalOutputs - 1).toCGFloat) : 0

    // If destination is below, and we have more than one edge,
    // we move each edge's y split point downward.
    if destinationBelow {
        // move halfway point lower = larger y
        return (from.y + distance/2)
            + shiftPerEdge.magnitude // move down
            - shiftFromTotalEdgeCount
    } else {
        return (from.y - distance/2)
            + shiftPerEdge.magnitude
            - shiftFromTotalEdgeCount
    }
}

// actual distance
func indexRise(_ fromIndex: Int,
               totalOutputs: Int) -> CGFloat {
    -indexRiseUp(fromIndex,
                 totalOutputs: totalOutputs).toCGFloat * 48
}

// just the inverse index,
// e.g. for 3 outputs total, first output will be 2, second will be 1, third 0
func indexRiseUp(_ fromIndex: Int,
                 totalOutputs: Int) -> Int {
    totalOutputs - fromIndex
}

// Originally:  let extends: CGFloat = 80
let inactiveExtends: CGFloat = 40

func from_extends(_ from: CGPoint,
                  _ to: CGPoint,
                  fromIndex: Int,
                  firstFrom: CGPoint,
                  firstTo: CGPoint,
                  lastFrom: CGPoint,
                  totalOutputs: Int,
                  useLegacy: Bool,
                  isActivelyDragged: Bool) -> CGFloat {

    if useLegacy {
        let activeExtends: CGFloat = (to.x - from.x).magnitude
        let useActiveExtends = isActivelyDragged && (activeExtends.magnitude < inactiveExtends)
        let extends: CGFloat = useActiveExtends ? activeExtends : inactiveExtends
        //        log("from_extends: using legacy extends")
        return extends
    }

    let destinationBelow = destinationIsBelow(from, to)
    let activeExtends: CGFloat = (to.x - from.x).magnitude
    let belowExtends = inactiveExtends + (24 * indexRiseUp(fromIndex,
                                                           totalOutputs: totalOutputs)).toCGFloat
    let aboveExtends = inactiveExtends + (24 * CGFloat(fromIndex - 1))
    //    let aboveExtends = inactiveExtends + (24 * CGFloat(fromIndex - 1)) - 16
    //    let aboveExtends = inactiveExtends + (24 * CGFloat(fromIndex - 1)) - 20

    //    let belowExtends = 0 + (24 * indexRiseUp(fromIndex,
    //                                             totalOutputs: totalOutputs)).toCGFloat
    //    let aboveExtends = 0 + (24 * CGFloat(fromIndex - 1))

    let useActiveExtends = isActivelyDragged && (activeExtends.magnitude < (destinationBelow ? belowExtends : aboveExtends))

    //    log("from_extends: activeExtends: \(activeExtends)")
    //    log("from_extends: belowExtends: \(belowExtends)")
    //    log("from_extends: aboveExtends: \(aboveExtends)")

    // Actively-dragged edges use special extension calculation
    if useActiveExtends {
        //        log("from_extends: using active extends")
        return activeExtends
    }

    // new style static edges use a more complex extension
    if destinationBelow {
        //        log("from_extends: using below extends")
        return belowExtends
    } else {
        //        log("from_extends: using above extends")
        return aboveExtends
    }
}

func to_extends(_ from: CGPoint,
                _ to: CGPoint,
                fromIndex: Int,
                firstFrom: CGPoint,
                firstTo: CGPoint,
                lastFrom: CGPoint,
                totalOutputs: Int,
                useLegacy: Bool,
                isActivelyDragged: Bool) -> CGFloat {

    // legacy logic
    if useLegacy {
        let activeExtends: CGFloat = (to.x - from.x).magnitude
        let useActiveExtends = isActivelyDragged && (activeExtends.magnitude < inactiveExtends)
        let extends: CGFloat = useActiveExtends ? activeExtends : inactiveExtends
        //        log("to_extends: using legacy extends")
        return extends
    }

    // new style logic
    let destinationBelow = destinationIsBelow(from, to)
    let activeExtends: CGFloat = (to.x - from.x).magnitude
    let belowExtends = inactiveExtends + (24 * (fromIndex - 1).toCGFloat)

    let aboveExtends = inactiveExtends + (24 * indexRiseUp(fromIndex, totalOutputs: totalOutputs).toCGFloat)

    //    let aboveExtends = inactiveExtends + (24 * indexRiseUp(fromIndex, totalOutputs: totalOutputs).toCGFloat) - 16
    //    let aboveExtends = inactiveExtends + (24 * indexRiseUp(fromIndex, totalOutputs: totalOutputs).toCGFloat) - 20

    //    let aboveExtends = inactiveExtends + (24 * indexRiseUp(fromIndex, totalOutputs: totalOutputs).toCGFloat) + 16

    //    let belowExtends = 0 + (24 * (fromIndex - 1).toCGFloat)
    //    let aboveExtends = 0 + (24 * indexRiseUp(fromIndex, totalOutputs: totalOutputs).toCGFloat)

    let useActiveExtends = isActivelyDragged && (activeExtends.magnitude < (destinationBelow ? belowExtends : aboveExtends))

    // log("to_extends: activeExtends: \(activeExtends)")
    // log("to_extends: belowExtends: \(belowExtends)")
    // log("to_extends: aboveExtends: \(aboveExtends)")

    // Actively-dragged edges use special extension calculation
    if useActiveExtends {
        // log("to_extends: using active extends")
        return activeExtends
    }

    // new style static edges use a more complex extension
    if destinationBelow {
        // log("to_extends: using below extends")
        return belowExtends
    } else {
        // log("to_extends: using above extends")
        return aboveExtends
    }
}

extension CGPoint {
    var rounded: Self {
        .init(x: self.x.rounded(), y: self.y.rounded())
    }
}

// `from` and `to` should be the fromExtension and toExtension;
// i.e. the question is: "If we were to
func useBackwardEdge(from: CGPoint,
                     to: CGPoint,
                     isActivelyDragged: Bool) -> Bool {

    // We need to round these before we create the diff,
    // since Swift can sometimes fluctuate between
    // eg `39.999`, `40.003` etc.
    let fromRounded = from.x.rounded()
    let toRounded = to.x.rounded()
    let diff = toRounded - fromRounded

    //    #if DEV_DEBUG
    // log("useBackwardEdge: to.x: \(to.x)")
    // log("useBackwardEdge: from.x: \(from.x)")
    // log("useBackwardEdge: toRounded: \(toRounded)")
    // log("useBackwardEdge: fromRounded: \(fromRounded)")
    // log("useBackwardEdge: diff: \(diff)")
    //    #endif

    //    return diff < 40
    //    return diff < relevantExtends
    //
    if isActivelyDragged {

        //        let willUseBackwardEdge = to.x <= from.x
        let adjustedFromRounded = fromRounded + 6
        let toBehindFrom = toRounded <= adjustedFromRounded
        // log("useBackwardEdge: actively dragged: adjustedFromRounded: \(adjustedFromRounded)")
        // log("useBackwardEdge: actively dragged: toBehindFrom: \(toBehindFrom)")
        return toBehindFrom
    }
    //
    //    // slight adjustment for when edge already exists,
    //    else

    if diff < MINIMUM_FORWARD_FACING_NODE_DISTANCE {
        // log("useBackwardEdge: will use backward edge")
        return true
    } else {
        // log("useBackwardEdge: will NOT use backward edge")
        return false
    }
}
