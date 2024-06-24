//
//  FromHSLToColor.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/2/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UIKit

extension HSLColor {
    var toColor: Color {
        let color = self
        return Color(hue: color.hue,
                     saturation: color.saturation,
                     lightness: color.lightness,
                     opacity: color.alpha)
    }
}

// HSL -> Color
extension Color {

    // Color constructor that converts from SwiftUI's HSB to HSL
    init(hue: Double,
         saturation: Double,
         lightness: Double,
         opacity: Double) {

        //        precondition(
        //            0...1 ~= hue &&
        //            0...1 ~= saturation &&
        //            0...1 ~= lightness &&
        //            0...1 ~= opacity,
        //            "input range is out of range 0...1")

        // Several options here?:
        // 1. keep the `precondition`, which crashes when condition not met
        // 2. change `hue`, `saturation` etc. to be within [0, 1]
        // 3. just use a guard let and log an error

        // From HSL TO HSB ---------
        var newSaturation: Double = 0.0

        let brightness = lightness + saturation * min(lightness, 1-lightness)

        if brightness == 0 { newSaturation = 0.0 } else {
            newSaturation = 2 * (1 - lightness / brightness)
        }
        // ---------

        self.init(hue: hue, saturation: newSaturation, brightness: brightness, opacity: opacity)
    }
}
