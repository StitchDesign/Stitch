//
//  BouncyConverterUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/6/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// The additional `_FromOrigamiValue` seems strange;
// the BouncyConverter apparently returns Origami friction and tension,
// which we then have to turn into "Rebound.js friction and tension"
// in order to match Origami's BouncyConverter node outputs and PopAnimation feel?
func convertBouncinessAndSpeedToFrictionAndTension(bounciness: Double,
                                                   speed: Double) -> (Double, Double) {

    // Convert bounciness and speed to friction and tension
    let k = BouncyConverter(bounciness: bounciness,
                            speed: speed)

    // NOTE: this is seems backward, i.e. like the BouncyConverter creates an Origami version value;
    // but the BouncyConverter in Rebound.js is for a SpringConfig
    // which their spring physics formula directly uses.
    // (Perhaps Rebound.js is handling their formula a little differently? Different powers etc.?)
    return (frictionFromOrigamiValue(k.bouncyFriction),
            tensionFromOrigamiValue(k.bouncyTension))
}

// https://github.com/facebookarchive/rebound-js/blob/master/src/OrigamiValueConverter.js

func tensionFromOrigamiValue(_ oValue: Double) -> Double {
    return (oValue - 30.0) * 3.62 + 194.0
}

func frictionFromOrigamiValue(_ oValue: Double) -> Double {
    return (oValue - 8.0) * 3.0 + 25.0
}

