//
//  StitchSyntax.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/25.
//

import Foundation
import SwiftUI
import SwiftSyntax
import SwiftParser

struct ViewNode {
    var name: String // the name of the SwiftUI View
    var arguments: [Argument] // arguments for the View, e.g. ("systemName", "star.fill") for Image(systemName: "star.fill")
    var modifiers: [Modifier] // modifiers for the View, e.g. .padding()
    var children: [ViewNode]
    var id: String  // Unique identifier for the node
}

struct Modifier {
    let kind: ViewModifierKind
    var arguments: [Argument]   // always at least one; an empty call gets a single “unknown” argument
}

struct Argument {
    let label: String?
    let value: String
    let syntaxKind: ArgumentKind // literal vs declared var vs expression
}

/// Exhaustive (for now) list of SwiftUI modifiers we actively recognise.
/// (No such list or enum is otherwise already exposed by SwiftUI for us programmatically.)
/// `rawValue` is **always** the textual name of the modifier as it appears in
/// source (e.g. `"fill"`, `"frame"`). Any unknown name is stored using `.custom`.
enum ViewModifierKind: Codable, Hashable {
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
    // …add more as needed …

    /// Any modifier name not yet mapped to a first-class case.
    case custom(String)
}

// MARK: - RawRepresentable conformance
extension ViewModifierKind: RawRepresentable {
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
        case .custom(let name):  return name
        }
    }
}

/// High‑level classification of an argument encountered in SwiftUI code.
enum ArgumentKind {
    
    /*
     ```swift
     Rectangle().fill(.blue).opacity(0.5)
     ```
     i.e. `FloatLiteralExprSyntax` etc.
     VPL equivalent = manually set input
     */
    case literal(LiteralKind)          // e.g. `.red`, `42`, `"hello"`
    
    /*
     ```swift
     let x = 0.5
     Rectangle().fill(.blue).opacity(x)
     ```
     i.e. `DeclReferenceExprSyntax`
     VPL equivalent = incoming edge
     */
    case variable(VariableKind)        // e.g. `someVar`, `self.count`
    
    /*
     ```swift
     Rectangle().fill(.blue).opacity(0.25 + 0.25)
     Rectangle().fill(.blue).opacity(max(0.3, 0.5))
     ```
     i.e. `InfixOperatorExprSyntax`, `FunctionCallExprSyntax`
     VPL equivalent = incoming edge
     */
    case expression(ExpressionKind)    // e.g. `1 + 1`, `min(10, 20)`
}

/// More granular breakdown of literal forms we might see in SwiftSyntax.
enum LiteralKind: String {
    case integer          = "IntegerLiteral"        // `42`
    case float            = "FloatLiteral"          // `3.14`
    case string           = "StringLiteral"         // `"hello"`
    case boolean          = "BooleanLiteral"        // `true`, `false`
    case nilLiteral       = "NilLiteral"            // `nil`
    case array            = "ArrayLiteral"          // `[1, 2, 3]`
    case dictionary       = "DictionaryLiteral"     // `["a": 1]`
    case tuple            = "TupleLiteral"          // `(x: 1, y: 2)`
    case regex            = "RegexLiteral"          // `/foo.+bar/`
    case colorLiteral     = "ColorLiteral"          // `#colorLiteral(...)`
    case imageLiteral     = "ImageLiteral"          // `#imageLiteral(...)`
    case fileLiteral      = "FileLiteral"           // `#fileLiteral(...)`
    case unknown          = "UnknownLiteral"
}

/// Possible syntactic shapes for a variable reference.
enum VariableKind: String {
    case identifier       = "Identifier"            // `x`
    case memberAccess     = "MemberAccess"          // `object.property`
}

/// Broad categories of non‑literal expressions.
enum ExpressionKind: String {
    case infixOperator    = "InfixOperator"         // `a + b`
    case prefixOperator   = "PrefixOperator"        // `-x`
    case postfixOperator  = "PostfixOperator"       // `array!`
    case functionCall     = "FunctionCall"          // `min(1, 2)`
    case ternary          = "TernaryConditional"    // `cond ? x : y`
    case tuple            = "TupleExpr"             // `(x, y)`
    case closure          = "Closure"               // `{ ... }`
    case unknown          = "UnknownExpr"
}
