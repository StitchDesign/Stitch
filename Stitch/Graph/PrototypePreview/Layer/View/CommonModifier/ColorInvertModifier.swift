//
//  ColorInvertModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

struct ColorInvertModifier: ViewModifier {
    let colorInvert: Bool
    
    func body(content: Content) -> some View {
        
        // TODO: use a UIKit view to invert-color instead? use `UIColor.inverseColor` (but would not work on e.g. Mapview) ?
        // For now we use `.hueRotation(180)`, but its alpha is not quite correct
        content.hueRotation(colorInvert ? Angle(degrees: 180) : Angle(degrees: 0))

        
        // NOTE: cannot use native SwiftUI .colorInvert() modifier since the if/else invalidates the view (thus breaking gestures), and .colorInvert() does not take any parameters.
//        if colorInvert {
//            content.colorInvert()
//        } else {
//            content
//        }
    }
}

extension UIColor {
    func inverseColor() -> UIColor {
        var alpha: CGFloat = 1.0
        
        var red: CGFloat = 0.0, green: CGFloat = 0.0, blue: CGFloat = 0.0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            return UIColor(red: 1.0 - red, green: 1.0 - green, blue: 1.0 - blue, alpha: alpha)
        }
        
        var hue: CGFloat = 0.0, saturation: CGFloat = 0.0, brightness: CGFloat = 0.0
        if self.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) {
            return UIColor(hue: 1.0 - hue, saturation: 1.0 - saturation, brightness: 1.0 - brightness, alpha: alpha)
        }
        
        var white: CGFloat = 0.0
        if self.getWhite(&white, alpha: &alpha) {
            return UIColor(white: 1.0 - white, alpha: alpha)
        }
        
        return self
    }
}
