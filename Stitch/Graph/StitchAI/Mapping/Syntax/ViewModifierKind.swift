//
//  ViewModifierKind.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/23/25.
//

import Foundation
import SwiftUI


// TODO: this list falls very short of being the full list of SwiftUI view modifiers

/// Exhaustive (for now) list of SwiftUI modifiers we actively recognise.
/// (No such list or enum is otherwise already exposed by SwiftUI for us programmatically.)
/// `rawValue` is **always** the textual name of the modifier as it appears in
/// source (e.g. `"fill"`, `"frame"`). Any unknown name is stored using `.custom`.
enum ModifierKind: Codable, Hashable {
    case fill
    case frame
    case padding
    case foregroundColor
    case opacity
    case cornerRadius
    case blur
    case scaleEffect
    case hueRotation
    case rotation3DEffect
    case rotationEffect
    case zIndex
    case blendMode
    case brightness
    case colorInvert
    case saturation
    case disabled
    case background
    case font
    case multilineTextAlignment
    case underline
    case keyboardType
    case disableAutocorrection
    case contrast
    case clipped
    case position
    case offset
    // …add more as needed …

    /// Any modifier name not yet mapped to a first-class case.
    case custom(String)
}

// MARK: - RawRepresentable conformance
extension ModifierKind: RawRepresentable {
    init(rawValue: String) {
        switch rawValue {
        case "fill":              self = .fill
        case "frame":             self = .frame
        case "padding":           self = .padding
        case "foregroundColor":   self = .foregroundColor
        case "opacity":           self = .opacity
        case "cornerRadius":      self = .cornerRadius
        case "blur":              self = .blur
        case "scaleEffect":       self = .scaleEffect
        case "hueRotation":       self = .hueRotation
        case "rotationEffect":    self = .rotationEffect
        case "rotation3DEffect":  self = .rotation3DEffect
        case "zIndex":            self = .zIndex
        case "blendMode":         self = .blendMode
        case "brightness":        self = .brightness
        case "colorInvert":       self = .colorInvert
        case "saturation":        self = .saturation
        case "disabled":          self = .disabled
        case "background":        self = .background
        case "font":              self = .font
        case "multilineTextAlignment":
                                   self = .multilineTextAlignment
        case "underline":         self = .underline
        case "keyboardType":      self = .keyboardType
        case "disableAutocorrection":
                                   self = .disableAutocorrection
        case "contrast":          self = .contrast
        case "clipped":           self = .clipped
        case "position":          self = .position
        case "offset":            self = .offset
        default:                  self = .custom(rawValue)
        }
    }

    var rawValue: String {
        switch self {
        case .fill:              return "fill"
        case .frame:             return "frame"
        case .padding:           return "padding"
        case .foregroundColor:   return "foregroundColor"
        case .opacity:           return "opacity"
        case .cornerRadius:      return "cornerRadius"
        case .blur:              return "blur"
        case .scaleEffect:       return "scaleEffect"
        case .hueRotation:       return "hueRotation"
        case .rotation3DEffect:  return "rotation3DEffect"
        case .rotationEffect:    return "rotationEffect"
        case .zIndex:            return "zIndex"
        case .blendMode:         return "blendMode"
        case .brightness:        return "brightness"
        case .colorInvert:       return "colorInvert"
        case .saturation:        return "saturation"
        case .disabled:          return "disabled"
        case .background:        return "background"
        case .font:              return "font"
        case .multilineTextAlignment:
                                    return "multilineTextAlignment"
        case .underline:         return "underline"
        case .keyboardType:      return "keyboardType"
        case .disableAutocorrection:
                                    return "disableAutocorrection"
        case .contrast:          return "contrast"
        case .clipped:           return "clipped"
        case .position:          return "position"
        case .offset:            return "offset"
        case .custom(let name):  return name
        }
    }
}
