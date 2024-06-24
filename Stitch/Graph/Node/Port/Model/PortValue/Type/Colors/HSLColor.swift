//
//  HSL.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/28/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UIKit

struct HSLColor: Equatable {
    var hue: CGFloat
    var saturation: CGFloat
    var lightness: CGFloat
    var alpha: CGFloat

    static let empty = Self.init(hue: 0, saturation: 0, lightness: 0, alpha: 0)
}

// https://stackoverflow.com/questions/62632213/swift-use-hsl-color-space-instead-of-standard-hsb-hsv
extension UIColor {
    convenience init(hue: CGFloat,
                     saturation: CGFloat,
                     lightness: CGFloat,
                     alpha: CGFloat) {

        precondition(0...1 ~= hue &&
                        0...1 ~= saturation &&
                        0...1 ~= lightness &&
                        0...1 ~= alpha, "input range is out of range 0...1")

        // From HSL TO HSB ---------
        var newSaturation: CGFloat = 0.0

        let brightness = lightness + saturation * min(lightness, 1-lightness)

        if brightness == 0 { newSaturation = 0.0 } else {
            newSaturation = 2 * (1 - lightness / brightness)
        }
        // ---------

        self.init(hue: hue, saturation: newSaturation, brightness: brightness, alpha: alpha)
    }
}

extension Color {
    var toUIColor: UIColor {
        UIColor(self)
    }

    var hsl: HSLColor {
        self.toUIColor.hsl
    }

    static let empty = falseColor
}
