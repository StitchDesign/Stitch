//
//  Modifier.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftSyntax
import SwiftParser


struct SyntaxViewModifier: Equatable, Hashable, Sendable, Codable {

    // representation of a SwiftUI view modifier name
    let name: SyntaxViewModifierName
    
    // representation of argument(s) to SwiftUI view modifer
    var arguments: [SyntaxViewModifierArgument]
}


/*
 TODO: some arguments to SwiftUI View constructors are void callbacks (= patch logic?) or SwiftUI views (= another ViewNode)
 TODO: `Argument.value` should be `enum ArgumentValue { case value(String), actionClosure(???), viewClosure(ViewNode) }`
 
 Note: per chat with Vatsal, can also ask LLM to rewrite certain SwiftUI View closure-styles into non-closure versions etc. in an additional pass.

 ```swift
 Button(
    action: { ... }, // patch logic?
    label: { ViewNode }
 )
 ```
 */
struct SyntaxViewModifierArgument: Equatable, Hashable, Sendable, Codable {
    let label: SyntaxViewModifierArgumentLabel
    let value: SyntaxViewModifierArgumentType
}


/*
 A single given parameter (i.e. a single label)
 could have a complex (more than just string) value or even multiple associated values, e.g.
 
 ```swift
 Rectangle()
     .rotation3DEffect(
        .degrees(90), // unlabeled, with non-string type
        axis: (x: 1, y: 0, z: 0) // labeled, with multiple associated values
    )
 ```
 */
enum SyntaxViewModifierArgumentType: Equatable, Hashable, Sendable, Codable {
    
    // e.g. .opacity(5.0)
    case simple(SyntaxViewModifierArgumentData)
    
    // e.g. .rotationEffect(.degrees(90), axis: ...)
    case angle(SyntaxViewModifierArgumentAngle)
    
    // e.g. .rotationEffect(..., axis: (x: 1, y: 0, z: 0))
    case axis(x: SyntaxViewModifierArgumentData,
              y: SyntaxViewModifierArgumentData,
              z: SyntaxViewModifierArgumentData)
}

extension SyntaxViewModifierArgumentType {
    var simpleValue: String? {
        switch self {
        case .simple(let data):
            return data.value
            
        default:
            return nil
        }
    }
}

// TODO: JULY 2: the argument .rotation3DEffect(_ angle: Angle) could be either Angle.degrees or Angle.radians, but Stitch's rotation layer inputs always uses degrees
// https://developer.apple.com/documentation/swiftui/view/rotation3deffect(_:axis:anchor:)
// https://developer.apple.com/documentation/swiftui/angle
enum SyntaxViewModifierArgumentAngle: Equatable, Hashable, Sendable, Codable {
    case degrees(SyntaxViewModifierArgumentData) //
    case radians(SyntaxViewModifierArgumentData)
    
    var value: String {
        switch self {
        case .degrees(let x):
            return x.value
        case .radians(let x):
            return x.value
        }
    }
}

struct SyntaxViewModifierArgumentData: Equatable, Hashable, Sendable, Codable {
    let value: String
    
    // literal vs declared var vs expression
    let syntaxKind: SyntaxArgumentKind
}


enum SyntaxViewModifierArgumentLabel: String, Equatable, Hashable, Sendable, Codable {
    case noLabel = "", // e.g. `.fill(Color.red)`, `.foregroundColor(Color.green)`
         
         // e.g. `.frame(width:height:alignment:)`
         width = "width",
         height = "height",
         alignment = "alignment",
         
         // e.g. position(x:y:)
         x = "x",
         y = "y",
    
         // e.g. .rotation3DEffect(..., axis: ...)
         axis = "axis"
}

extension SyntaxViewModifierArgumentLabel {
    static func from(_ string: String?) -> SyntaxViewModifierArgumentLabel? {
        switch string {
        case .none:
            return .noLabel
        case .some(let x):
            return Self(rawValue: x)
        }
    }
}


// MARK: representation of

// TODO: this list falls very short of being the full list of SwiftUI view modifiers

/// Exhaustive (for now) list of SwiftUI modifiers we actively recognise.
/// (No such list or enum is otherwise already exposed by SwiftUI for us programmatically.)
/// `rawValue` is **always** the textual name of the modifier as it appears in
/// source (e.g. `"fill"`, `"frame"`). Any unknown name is stored using `.custom`.
enum SyntaxViewModifierName: String, Codable, Hashable, Equatable, Sendable {
    case fill = "fill"
    case frame = "frame"
    case padding = "padding"
    case foregroundColor = "foregroundColor"
    case opacity = "opacity"
    case cornerRadius = "cornerRadius"
    case blur = "blur"
    case scaleEffect = "scaleEffect"
    case hueRotation = "hueRotation"
    case rotation3DEffect = "rotation3DEffect"
    case rotationEffect = "rotationEffect"
    case zIndex = "zIndex"
    case blendMode = "blendMode"
    case brightness = "brightness"
    case colorInvert = "colorInvert"
    case saturation = "saturation"
    case disabled = "disabled"
    case background = "background"
    case font = "font"
    case multilineTextAlignment = "multilineTextAlignment"
    case underline = "underline"
    
    // TODO: support after v1
//    case keyboardType = "keyboardType"
    
    case disableAutocorrection = "disableAutocorrection"
    case contrast = "contrast"
    case clipped = "clipped"
    case position = "position"
    case offset = "offset"
    case id = "id"
    
    // …add more as needed …
}
