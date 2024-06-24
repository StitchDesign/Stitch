//
//  RGBA.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/5/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// The RGBa components of a color

extension RGBA {
    var toUIColor: UIColor {
        UIColor(red: self.red,
                green: self.green,
                blue: self.blue,
                alpha: self.alpha)
    }

    var toColor: Color {
        Color(uiColor: self.toUIColor)
    }

    func fromColor(_ color: Color) -> RGBA {
        color.asRGBA
    }

    func fromUIColor(_ uiColor: UIColor) -> RGBA {
        Color(uiColor: uiColor).asRGBA
    }
}

extension Color {
    init(rgba: RGBA) {
        self = rgba.toColor
    }

    var asRGBA: RGBA {
        if let components = colorComponents {
            return RGBA(red: components.red,
                        green: components.green,
                        blue: components.blue,
                        alpha: components.alpha)
        } else {
            // When can we fail to retrieve colors?
            log("Color.asRGBA: failed to retrieve color components")
            return RGBA(red: 0, green: 0, blue: 0, alpha: 1)
        }
    }
}
