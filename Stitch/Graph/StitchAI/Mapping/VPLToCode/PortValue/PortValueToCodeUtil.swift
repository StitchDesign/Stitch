//
//  StitchToCodeUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/7/25.
//

import SwiftUI

/// Converts color names to hex values for PortValueDescription
func colorToHex(_ colorName: String) -> String {
    switch colorName.lowercased() {
    case "red":
        return "FF0000FF"
    case "green":
        return "00FF00FF"
    case "blue":
        return "0000FFFF"
    case "white":
        return "FFFFFFFF"
    case "black":
        return "000000FF"
    case "yellow":
        return "FFFF00FF"
    case "orange":
        return "FFA500FF"
    case "purple":
        return "800080FF"
    case "pink":
        return "FFC0CBFF"
    case "gray", "grey":
        return "808080FF"
    case "clear":
        return "00000000"
    default:
        return "808080FF" // Default to gray
    }
}

/// Maps a view modifier context to the appropriate PortValueDescription value_type
func getPortValueDescriptionType(for modifierName: String, argumentIndex: Int = 0) -> String {
    switch modifierName {
    case "fill", "foregroundColor":
        return "color"
    case "frame":
        return "size"
    case "opacity", "brightness", "contrast", "saturation", "scaleEffect", "zIndex":
        return "number"
    case "cornerRadius", "blur":
        return "number"
    case "position", "offset":
        return "position"
    case "padding":
        return "padding"
    case "font":
        return "textFont"
    case "fontWeight":
        return "textFont"
    case "fontDesign":
        return "textFont"
    case "layerId":
        return "string"
    default:
        // Default fallback
        return "string"
    }
}
