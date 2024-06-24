//
//  HexColors.swift
//  Stitch
//
//  Created by Christian J Clampitt on 11/2/23.
//

import Foundation
import StitchSchemaKit
import SwiftUI
import UIKit

// namespace for color conversion helpers
struct ColorConversionUtils {

    // Hex -> Color via UIColor
    static func hexToColor(_ hex: String) -> Color? {
        UIColor(hex: hex)?.toColor
    }

    // Color -> Hex via UIColor
    static func colorToHex(_ color: Color) -> String? {
        color.toUIColor.toHex(alpha: true)
    }
}

// https://blog.eidinger.info/from-hex-to-color-and-back-in-swiftui

extension Color {
    var toHex: String? {
        ColorConversionUtils.colorToHex(self)
    }

    var asHexDisplay: String {
        self.toHex.map { "#\($0)" } ?? self.description
    }

    static let defaultFalseColorHex = falseColor.asHexDisplay

}

// https://www.hackingwithswift.com/example-code/uicolor/how-to-convert-a-hex-color-to-a-uicolor
extension UIColor {

    var toColor: Color {
        Color(uiColor: self)
    }

    // MARK: - Initialization

    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt32 = 0

        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 1.0

        //          let length = hexSanitized.characters.count
        let length = hexSanitized.count

        guard Scanner(string: hexSanitized).scanHexInt32(&rgb) else { return nil }

        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0

        } else if length == 8 {
            r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            a = CGFloat(rgb & 0x000000FF) / 255.0

        } else {
            return nil
        }

        self.init(red: r, green: g, blue: b, alpha: a)
    }

    // https://cocoacasts.com/from-hex-to-uicolor-and-back-in-swift#:~:text=From%20UIColor%20to%20Hex%20in,is%20returned%20from%20the%20method
    var toHex: String? {
        return toHex()
    }

    // MARK: - From UIColor to String

    // Default to true
    //    func toHex(alpha: Bool = false) -> String? {
    func toHex(alpha: Bool = true) -> String? {
        guard let components = cgColor.components, components.count >= 3 else {
            return nil
        }

        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)

        if components.count >= 4 {
            a = Float(components[3])
        }

        if alpha {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }

}
