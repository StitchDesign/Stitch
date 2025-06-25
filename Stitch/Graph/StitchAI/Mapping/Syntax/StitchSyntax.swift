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
    
    // arguments for the View, e.g. ("systemName", "star.fill") for Image(systemName: "star.fill")
    var constructorArguments: [ConstructorArgument]
    
    var modifiers: [Modifier] // modifiers for the View, e.g. .padding()
    
    var children: [ViewNode]
    
    // TODO: use UUID
    var id: String  // Unique identifier for the node
}

struct Modifier: Equatable, Hashable {
    let kind: ModifierKind
    var arguments: [Argument]   // always at least one; an empty call gets a single “unknown” argument
}

struct ConstructorArgument: Equatable, Hashable {
    
    /*
     TODO: combine labels + values ? how to elegantly handle difference between no args like `Rectangle`, un-labeled args like `Text("love")` and labeled args like `Image(systemName:)`
     
     Note: `Rectangle()` actually takes NO constructor arguments
     
     */
    let label: ConstructorArgumentLabel
    
    // Note: some SwiftUI view modifiers "do not take an argument" (e.g. `.padding()`; though this is technically just defaulting to a default argument), BUT EVERY CONSTRUCTOR FOR A SWIFTUI VIEW TAKES AN ARGUMENT, so this is non-optional
    let value: String
    
    let syntaxKind: ArgumentKind // literal vs declared var vs expression
}

// TODO: a way to represent the type of the SwiftUI View constructor arg ?
// Note: this can only really properly be resolved into a LayerInputPort with the help of the known layer
enum ConstructorArgumentLabel: String, Equatable, Hashable {
    
    
    // argument without a label, e.g. SwiftUI Text: `Text("love")`;
    // Note: SwiftUI views that do not take arguments at all (e.g. `Rectangle()`) will not actually have constructor-args
    // https://developer.apple.com/documentation/swiftui/text#Creating-a-text-view
    case unlabeled = ""
    
    
    // SwiftUI Image
    // https://developer.apple.com/documentation/swiftui/image#Creating-an-image
    case systemName = "systemName"
    
    // HStack, VStack, ZStack
    // case alignment = "alignment"
    // case spacing = "spacing"
    
    //    case hStack(HStackConstructorArgument)
    //    case vStack(VStackConstructorArgument)
    
    // Use `Argument` to capture unsupported constructors on SwiftUI Views,
    // e.g. `Text(Date, style: Text.DateStyle)`
    
    // Rather than keeping around which argument was unsupported, we should log at the given site etc. and react
    case unsupported //(Argument)
}

extension ConstructorArgumentLabel {
    static func from(_ string: String?) -> ConstructorArgumentLabel? {
        switch string {
        case .none:
            return .unlabeled
        case .some(let x):
            return Self(rawValue: x)
        }
    }
}


// TODO: have ChatGPT crawl SwiftUI documentation for constructors (usually the "Creating a ..." section) and define more `ConstructorArgument` cases

// https://developer.apple.com/documentation/swiftui/hstack#Creating-a-stack
struct HStackConstructorArgument: Equatable, Hashable {
    let alignment: String // VerticalAlignment
    let spacing: CGFloat?
    let content: ViewNode
}

// https://developer.apple.com/documentation/swiftui/vstack#Creating-a-stack
struct VStackConstructorArgument: Equatable, Hashable {
    let alignment: String // HorizontalAlignment
    let spacing: CGFloat?
    let content: ViewNode
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

extension ArgumentKind {
    static func fromExpression(_ expression: ExprSyntax) -> Self {
        
        // Determine argument type clearly:
        let kind: ArgumentKind // = .literal(.unknown)
                    
        // Literals
        if expression.is(IntegerLiteralExprSyntax.self) {
            kind = .literal(.integer)
        } else if expression.is(FloatLiteralExprSyntax.self) {
            kind = .literal(.float)
        } else if expression.is(StringLiteralExprSyntax.self) {
            kind = .literal(.string)
        } else if expression.is(BooleanLiteralExprSyntax.self) {
            kind = .literal(.boolean)
        } else if expression.is(NilLiteralExprSyntax.self) {
            kind = .literal(.nilLiteral)
        } else if expression.is(ArrayExprSyntax.self) {
            kind = .literal(.array)
        } else if expression.is(DictionaryExprSyntax.self) {
            kind = .literal(.dictionary)
        } else if expression.is(TupleExprSyntax.self) {
            kind = .literal(.tuple)
        } else if expression.is(RegexLiteralExprSyntax.self) {
            kind = .literal(.regex)
        }
        
        //            else if expression.is(ColorLiteralExprSyntax.self) {
        //                kind = .literal(.colorLiteral)
        //            } else if expression.is(ImageLiteralExprSyntax.self) {
        //                kind = .literal(.imageLiteral)
        //            } else if expression.is(FileLiteralExprSyntax.self) {
        //                kind = .literal(.fileLiteral)
        //            }
        //            else if expression.is(ObjectLiteralExprSyntax.self) {
        //                kind = .literal
        //            }
                   
        // Variables (includes modifier
        else if let declRef = expression.as(DeclReferenceExprSyntax.self) {
            if declRef.baseName.text.contains(".") {
                kind = .variable(.memberAccess)
            } else {
                kind = .variable(.identifier)
            }
            
        // Expressions
        } else if expression.is(InfixOperatorExprSyntax.self) {
            kind = .expression(.infixOperator)
        } else if expression.is(PrefixOperatorExprSyntax.self) {
            kind = .expression(.prefixOperator)
        } else if expression.is(PostfixOperatorExprSyntax.self) {
            kind = .expression(.postfixOperator)
        } else if expression.is(FunctionCallExprSyntax.self) {
            kind = .expression(.functionCall)
        } else if expression.is(TernaryExprSyntax.self) {
            kind = .expression(.ternary)
        } else if expression.is(TupleExprSyntax.self) {
            kind = .expression(.tuple)
        } else if expression.is(ClosureExprSyntax.self) {
            kind = .expression(.closure)
        }
        
        // unknown ? crash here?
        else {
            kind = .literal(.unknown)
        }
        
        return kind
    }
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
