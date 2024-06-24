//
//  ScrollFoundation.swift
//  Stitch
//
//  Created by Christian J Clampitt on 9/24/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// The foundational logic for all our scrolling.

let minimumScrollDistance: CGFloat = 8

// 1. once we decide to scroll, that should stay true for the entire gesture
// 2. should reduce the translation by 8 pixels
func shouldScroll(parentSize: CGSize,
                  childSize: CGSize,
                  dragGesture: DragGesture.Value) -> Bool {
    // Only scroll if child is taller than parent,
    // and we've moved at least 8 pixels up or down.
    (childSize.height > parentSize.height)
        && abs(dragGesture.translation.height) > 8
}

func distanceCalc(parentSize: Double,
                  childSize: Double,
                  childPosition: Double) -> Double {

    if childPosition > .zero {
        return childPosition
    }
    if (abs(childPosition) + parentSize) > childSize {
        return (abs(childPosition) + parentSize) - childSize
    }
    return .zero
}

func calculateDecay(distance: CGFloat) -> CGFloat {
    if distance <= 0.0 {
        return 1.0
    } else {
        // there's a cut off near 1000 pixals of movment with log10 and 3
        // where we stop movment and cut it it off -> drop to 0.0
        let d = 1 - (log10(distance))/3
        if d <= 0.0 {
            return 0.0
        } else {
            return d
        }
    }
}

func onScroll(translationSize: CGSize,
              previousPosition: CGPoint,
              position: CGPoint,
              size: CGSize,
              parentSize: CGSize) -> CGPoint {

    var translationHeight: CGFloat = 0
    var translationWidth: CGFloat = 0

    // Set height and width translation. A "decay" function is used to slow
    // down scrolling rate for more natural scroll
    translationHeight = decayScrollTranslation(
        translationDistance: translationSize.height,
        previousPosition: previousPosition.y,
        childSize: size.height,
        parentSize: parentSize.height)

    translationWidth = decayScrollTranslation(
        translationDistance: translationSize.width,
        previousPosition: previousPosition.x,
        childSize: size.width,
        parentSize: parentSize.width)

    let updatedPosition = updatePosition(position: previousPosition,
                                         width: translationWidth,
                                         height: translationHeight)
    return updatedPosition
}

// TODO: use scroll setting node's `decelerationRate` here
func decayScrollTranslation(translationDistance: Double,
                            previousPosition: Double,
                            childSize: Double,
                            parentSize: Double) -> Double {

    let isNegativeTranslation = translationDistance < 0

    let decayTranslation: Double = (0..<abs(Int(translationDistance)))
        .reduce(0, { (result: Double, translationStep: Int) in

            let newTranslation = isNegativeTranslation ? -translationStep : translationStep

            let newPosition = previousPosition + Double(newTranslation)

            let distance = distanceCalc(parentSize: parentSize,
                                        childSize: childSize,
                                        childPosition: newPosition)

            let decay = calculateDecay(distance: distance)

            return result + decay
        })

    return isNegativeTranslation ? -decayTranslation : decayTranslation
}
