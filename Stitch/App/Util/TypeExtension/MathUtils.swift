//
//  MathUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/1/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let NUMBER_LINE_ROUNDED_PLACES = 3

// was 250
// 1k also works
// 5k seems same as 1k, perf-wise
let defaultNumberLineSize: Int = 5000
// let defaultNumberLineSize: Int = 100
// let defaultNumberLineSize: Int = 100

// TODO: return OrderedSet<Double>
func constructNumberline(_ middle: Double,
                         // How many steps on each side up and down;
                         // eventually should be "infinite"?
                         stepCount: Int = defaultNumberLineSize,
                         stepScale: AdjustmentBarStepScale) -> [Double] {

    // log("\n constructNumberline called: middle \(middle), stepScale \(stepScale)")

    let highest = middle + (CGFloat(stepCount) * stepScale.stepScaleSize)
    let lowest = middle - (CGFloat(stepCount) * stepScale.stepScaleSize)

    // log("constructNumberline: lowest: \(lowest)")
    // log("constructNumberline: highest: \(highest)")

    // Note: when moving from high -> low, `by` must be < 0.
    let by = -stepScale.stepScaleSize

    let upperRange = stride(from: highest,
                            through: middle,
                            by: by)

    let lowerRange = stride(from: middle,
                            through: lowest,
                            by: by)

    //    log("constructNumberline: Array(upperRange): \(Array(upperRange))")
    //    log("constructNumberline: Array(lowerRange): \(Array(lowerRange))")

    // TODO: fix the ranges to be genuinely unique (OrderedSet);
    // don't rely on this costly iteration over the array.
    let ks = (Array(upperRange) + Array(lowerRange))
        .map { $0.rounded(toPlaces: NUMBER_LINE_ROUNDED_PLACES) }
        .uniqued()

    //    log("constructNumberline: ks: \(ks)")

    return ks
}

extension Double {
    var asPositiveZero: Double {
        self.isZero ? abs(self) : self
    }
}

extension CGFloat {
    var asPositiveZero: Double {
        self.isZero ? Swift.abs(self) : self
    }
}

func areEquivalent(n: Double,
                   n2: Double,
                   places: Int = 5) -> Bool {
    let rounded = n.rounded(toPlaces: places)
    let rounded2 = n2.rounded(toPlaces: places)
    //    log("areEquivalent: rounded: \(rounded)")
    //    log("areEquivalent: rounded2: \(rounded2)")
    return rounded == rounded2
}

extension Int {
    var toDouble: Double {
        Double(self)
    }
}
