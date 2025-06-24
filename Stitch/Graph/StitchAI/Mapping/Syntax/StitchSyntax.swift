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

struct ViewNode: Equatable, Hashable {
    var name: ViewKind  // strongly-typed SwiftUI view kind
//    var arguments: [Argument] // arguments for the View, e.g. ("systemName", "star.fill") for Image(systemName: "star.fill")
    var arguments: [ConstructorArgument]
    var modifiers: [Modifier] // modifiers for the View, e.g. .padding()
    var children: [ViewNode]
    var id: String  // Unique identifier for the node
}

struct Modifier: Equatable, Hashable {
    let kind: ModifierKind
    var arguments: [Argument]   // always at least one; an empty call gets a single “unknown” argument
}


enum ConstructorArgument: Equatable, Hashable {
    case image(ImageConstructorArgument)
    case text(TextConstructorArgument)
    
    //    case hStack(HStackConstructorArgument)
    //    case vStack(VStackConstructorArgument)
    
    // Use `Argument` to capture unsupported constructors on SwiftUI Views,
    // e.g. `Text(Date, style: Text.DateStyle)`
    case unsupported(Argument)
}

extension ConstructorArgument {
    var getImageConstructor: ImageConstructorArgument? {
        switch self {
        case .image(let x): return x
        default: return nil
        }
    }
    
    var getTextConstructor: TextConstructorArgument? {
        switch self {
        case .text(let x): return x
        default: return nil
        }
    }
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
struct Argument: Equatable, Hashable {
    let label: String?
    let value: String
    let syntaxKind: ArgumentKind // literal vs declared var vs expression
}


/// High‑level classification of an argument encountered in SwiftUI code.
enum ArgumentKind: Equatable, Hashable {
    
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
enum LiteralKind: String, Equatable, Hashable {
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
enum VariableKind: String, Equatable, Hashable {
    case identifier       = "Identifier"            // `x`
    case memberAccess     = "MemberAccess"          // `object.property`
}

/// Broad categories of non‑literal expressions.
enum ExpressionKind: String, Equatable, Hashable {
    case infixOperator    = "InfixOperator"         // `a + b`
    case prefixOperator   = "PrefixOperator"        // `-x`
    case postfixOperator  = "PostfixOperator"       // `array!`
    case functionCall     = "FunctionCall"          // `min(1, 2)`
    case ternary          = "TernaryConditional"    // `cond ? x : y`
    case tuple            = "TupleExpr"             // `(x, y)`
    case closure          = "Closure"               // `{ ... }`
    case unknown          = "UnknownExpr"
}
