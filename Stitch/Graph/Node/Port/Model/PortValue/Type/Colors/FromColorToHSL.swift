//
//  FromColorToHSL.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/2/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UIKit

extension Color {
    var toHSL: HSLColor {
        self.toUIColor.hsl
    }
}

// https://gist.github.com/adamgraham/3ada1f7f4cdf8131dd3d2d95bd116cfc
extension UIColor {

    var hsl: HSLColor {
        var (h, s, b, a) = (CGFloat(), CGFloat(), CGFloat(), CGFloat())
        getHue(&h,
               saturation: &s,
               brightness: &b,
               alpha: &a)

        let l = ((2.0 - s) * b) / 2.0

        switch l {
        case 0.0, 1.0:
            s = 0.0
        case 0.0..<0.5:
            s = (s * b) / (l * 2.0)
        default:
            s = (s * b) / (2.0 - l * 2.0)
        }

        return HSLColor(hue: h,  // * 360.0,
                        saturation: s, // * 100.0,
                        lightness: l, // * 100.0,
                        alpha: a)
    }

    /// Initializes a color from HSL (hue, saturation, lightness) components.
    /// - parameter hsl: The components used to initialize the color.
    /// - parameter alpha: The alpha value of the color.
    convenience init(_ hsl: HSLColor, alpha: CGFloat) {
        let h = hsl.hue // / 360.0
        var s = hsl.saturation // / 100.0
        let l = hsl.lightness // / 100.0

        let t = s * ((l < 0.5) ? l : (1.0 - l))
        let b = l + t
        s = (l > 0.0) ? (2.0 * t / b) : 0.0

        self.init(hue: h, saturation: s, brightness: b, alpha: alpha)
    }

}
