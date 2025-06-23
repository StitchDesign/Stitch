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


struct Argument {
    let label: String?
    let value: String
    let syntaxKind: ArgumentKind // literal vs declared var vs expression
}

struct Modifier {
    let name: String
    var arguments: [Argument]   // always at least one; an empty call gets a single “unknown” argument
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

// MARK: EXAMPLES

// Example for complex modifiers with multiple parameters
// SwiftUI code:
// Rectangle()
//     .frame(width: 200, height: 100, alignment: .center)
let complexModifierExample = ViewNode(
    name: "Rectangle",
    arguments: [],
    modifiers: [
        Modifier(
            name: "frame",
            arguments: [
                Argument(label: "width",  value: "200", syntaxKind: .literal(.integer)),
                Argument(label: "height", value: "100", syntaxKind: .literal(.integer)),
                Argument(label: "alignment", value: ".center", syntaxKind: .variable(.memberAccess))
            ]
        )
    ],
    children: [],
    id: "rectangle6"
)


// SwiftUI code:
// ZStack {
//     Rectangle().fill(Color.blue)
//     Rectangle().fill(Color.green)
// }
let example1 = ViewNode(
    name: "ZStack",
    arguments: [],
    modifiers: [],
    children: [
        ViewNode(
            name: "Rectangle",
            arguments: [],
            modifiers: [
                Modifier(
                    name: "fill",
                    arguments: [Argument(label: nil, value: "Color.blue", syntaxKind: .variable(.memberAccess))]
                )
            ],
            children: [],
            id: "rectangle1"
        ),
        ViewNode(
            name: "Rectangle",
            arguments: [],
            modifiers: [
                Modifier(
                    name: "fill",
                    arguments: [Argument(label: nil, value: "Color.green", syntaxKind: .variable(.memberAccess))]
                )
            ],
            children: [],
            id: "rectangle2"
        )
    ],
    id: "zstack1"
)


// SwiftUI code:
// Text("salut")
let example2 = ViewNode(
    name: "Text",
    arguments: [Argument(label: nil, value: "\"salut\"", syntaxKind: .literal(.string))],
    modifiers: [],
    children: [],
    id: "text1"
)

// SwiftUI code:
// Text("salut").foregroundColor(Color.yellow).padding()
let example3 = ViewNode(
    name: "Text",
    arguments: [Argument(label: nil, value: "\"salut\"", syntaxKind: .literal(.string))],
    modifiers: [
        Modifier(
            name: "foregroundColor",
            arguments: [Argument(label: nil, value: "Color.yellow", syntaxKind: .variable(.memberAccess))]
        ),
        Modifier(
            name: "padding",
            arguments: [Argument(label: nil, value: "", syntaxKind: .literal(.unknown))]
        )
    ],
    children: [],
    id: "text2"
)


// SwiftUI code:
// ZStack {
//     Rectangle().fill(Color.blue)
//     VStack {
//        Rectangle().fill(Color.green)
//        Rectangle().fill(Color.red)
//     }
// }
let example4 = ViewNode(
    name: "ZStack",
    arguments: [],
    modifiers: [],
    children: [
        ViewNode(
            name: "Rectangle",
            arguments: [],
            modifiers: [
                Modifier(
                    name: "fill",
                    arguments: [Argument(label: nil, value: "Color.blue", syntaxKind: .variable(.memberAccess))]
                )
            ],
            children: [],
            id: "rectangle3"
        ),
        ViewNode(
            name: "VStack",
            arguments: [],
            modifiers: [],
            children: [
                ViewNode(
                    name: "Rectangle",
                    arguments: [],
                    modifiers: [
                        Modifier(
                            name: "fill",
                            arguments: [Argument(label: nil, value: "Color.green", syntaxKind: .variable(.memberAccess))]
                        )
                    ],
                    children: [],
                    id: "rectangle4"
                ),
                ViewNode(
                    name: "Rectangle",
                    arguments: [],
                    modifiers: [
                        Modifier(
                            name: "fill",
                            arguments: [Argument(label: nil, value: "Color.red", syntaxKind: .variable(.memberAccess))]
                        )
                    ],
                    children: [],
                    id: "rectangle5"
                )
            ],
            id: "vstack1"
        )
    ],
    id: "zstack2"
)

// SwiftUI code:
// Image(systemName: "star.fill")

let example5 = ViewNode(
    name: "Image",
    arguments: [Argument(label: "systemName", value: "\"star.fill\"", syntaxKind: .literal(.string))],
    modifiers: [],
    children: [],
    id: "image1"
)

