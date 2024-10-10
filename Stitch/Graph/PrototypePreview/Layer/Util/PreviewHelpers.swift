//
//  PreviewHelpers.swift
//  Stitch
//
//  Created by cjc on 12/21/20.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let DEFAULT_MINIMUM_DRAG_DISTANCE: Double = 0.0

// Replaces native SwiftUI `.intersects` method,
// which produces unexpected intersections.
// This implementation assumes CGRect.origin is in center of rect.
func isIntersecting(_ r1: CGRect, _ r2: CGRect) -> Bool {

    if r1.origin == r2.origin {
        return true
    } else {
        // Difference between the two rects' origins
        let xDiff = abs(r1.origin.x - r2.origin.x)
        let yDiff = abs(r1.origin.y - r2.origin.y)

        //        log("isIntersecting: xDiff: \(xDiff)")
        //        log("isIntersecting: yDiff: \(yDiff)")

        let maxXDiff = r1.size.width/2 + r2.size.width/2
        let maxYDiff = r1.size.height/2 + r2.size.height/2

        //        log("isIntersecting: maxXDiff: \(maxXDiff)")
        //        log("isIntersecting: maxYDiff: \(maxYDiff)")

        if (yDiff < maxYDiff) && (xDiff < maxXDiff) {
            return true
        }

        return false
    }
}
