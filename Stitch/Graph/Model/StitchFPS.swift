//
//  StitchFPS.swift
//  Stitch
//
//  Created by Christian J Clampitt on 8/10/23.
//

import Foundation
import StitchSchemaKit

let STITCH_MIN_GRAPH_FPS: CGFloat = 0
let STITCH_MAX_GRAPH_FPS: CGFloat = 120

/// Convert a current, actual FPS (e.g. 88 FPS) to a progress along our min 0, max 120 graph FPS spectrum
func fpsAlongSpectrum(_ n: StitchFPS) -> Double {
    let x = progress(n.value,
                     start: STITCH_MIN_GRAPH_FPS,
                     end: STITCH_MAX_GRAPH_FPS)

    // Never let it go above 100% or below 0%
    if x > 1 {
        return 1
    } else if x < 0 {
        return 0
    } else {
        return x
    }
}

struct StitchFPS: Equatable {
    /*
     e.g. on a small, resting graph:
     - iPad Pro: 120 FPS
     - MacBook Air: 60 FPS

     On a larger, more perf-intensive graph, may drop below device's expected FPS,
     e.g. dragging cable on Humane Demo: may dip to 40 FPS even on iPad Pro.
     */
    let value: CGFloat

    init(_ value: CGFloat) {
        if value > 120 {
            //            #if DEV_DEBUG
            //            log("StitchFPS: init: value was too large: \(value)")
            //            #endif
            self.value = capFPS(120)
        } else if value < 10 {
            //            #if DEV_DEBUG
            //            log("StitchFPS: init: value was too small: \(value)")
            //            #endif
            self.value = 10
        } else {
            self.value = capFPS(CGFloat(value))
        }
        //        #if DEV_DEBUG
        //        log("StitchFPS: init: self.value: \(self.value)")
        //        #endif
    }

    static let defaultAssumedFPS: Self = .init(60)

}

func capFPS(_ value: CGFloat) -> CGFloat {

    #if targetEnvironment(macCatalyst)
    // Can never be faster than 60 FPS on Mac
    if value > 60 {
        return 60
    } else {
        return value
    }
    #else
    // Can never be faster than 120 FPS on iPad Pro
    if value > 120 {
        return 120
    } else {
        return value
    }
    #endif

}
