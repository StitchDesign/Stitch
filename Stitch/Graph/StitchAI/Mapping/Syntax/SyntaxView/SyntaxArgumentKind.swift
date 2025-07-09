//
//  SyntaxArgumentKind.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftSyntax


/// High‑level classification of an argument encountered in SwiftUI code.
enum SyntaxArgumentKind: Equatable, Hashable, Codable, Sendable {
    
    /*
     ```swift
     Rectangle().fill(.blue).opacity(0.5)
     ```
     i.e. `FloatLiteralExprSyntax` etc.
     VPL equivalent = manually set input
     */
    case literal(SyntaxArgumentLiteralKind) // e.g. `.red`, `42`, `"hello"`
    
    /*
     ```swift
     let x = 0.5
     Rectangle().fill(.blue).opacity(x)
     ```
     i.e. `DeclReferenceExprSyntax`
     VPL equivalent = incoming edge
     */
    case variable(SyntaxArgumentVariableKind) // e.g. `someVar`, `self.count`
    
    /*
     ```swift
     Rectangle().fill(.blue).opacity(0.25 + 0.25)
     Rectangle().fill(.blue).opacity(max(0.3, 0.5))
     ```
     i.e. `InfixOperatorExprSyntax`, `FunctionCallExprSyntax`
     VPL equivalent = incoming edge
     */
    case expression(SyntaxArgumentExpressionKind) // e.g. `1 + 1`, `min(10, 20)`
}

extension SyntaxArgumentKind {
    static func fromExpression(_ expression: ExprSyntax) -> Self? {
        
        // Determine argument type clearly:
        let kind: SyntaxArgumentKind // = .literal(.unknown)
                    
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
        } else if expression.is(MemberAccessExprSyntax.self) {
            kind = .literal(.memberAccess)
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
        }
            
        // Expressions
        else if expression.is(InfixOperatorExprSyntax.self) {
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
        
        else {
            return nil
        }
        
        return kind
    }
}

/// More granular breakdown of literal forms we might see in SwiftSyntax.
enum SyntaxArgumentLiteralKind: String, Equatable, Hashable, Codable {
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
    case memberAccess     = "MemberAccess"          // `Color.blue` or `.blue`
}

/// Possible syntactic shapes for a variable reference.
enum SyntaxArgumentVariableKind: String, Equatable, Hashable, Codable {
    case identifier       = "Identifier"            // `x`
    case memberAccess     = "MemberAccess"          // `object.property`
}

/// Broad categories of non‑literal expressions.
enum SyntaxArgumentExpressionKind: String, Equatable, Hashable, Codable {
    case infixOperator    = "InfixOperator"         // `a + b`
    case prefixOperator   = "PrefixOperator"        // `-x`
    case postfixOperator  = "PostfixOperator"       // `array!`
    case functionCall     = "FunctionCall"          // `min(1, 2)`
    case ternary          = "TernaryConditional"    // `cond ? x : y`
    case tuple            = "TupleExpr"             // `(x, y)`
    case closure          = "Closure"               // `{ ... }`
}

extension String {
    func stripQuotes() -> String {
        self
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }
}

extension SyntaxViewSimpleData {
    /// Used for eventual PortValue decoding. Only nil when a `nil` type is returned.
    func createEncoding() throws -> any Encodable {
        // raw literal text (removing quotes for strings)
        let raw = self.value.stripQuotes()
        
        switch self.syntaxKind {
        case .integer:
            guard let intValue = Int(raw) else {
                throw SwiftUISyntaxError.invalidIntegerLiteral(raw)
            }
            return intValue
            
        case .float:
            guard let doubleValue = Double(raw) else {
                throw SwiftUISyntaxError.invalidFloatLiteral(raw)
            }
            return doubleValue
            
        case .string:
            // Strip surrounding quotes
            let text = raw
            return text
            
        case .boolean:
            guard let boolValue = Bool(raw) else {
                throw SwiftUISyntaxError.invalidBooleanLiteral(raw)
            }
            return boolValue
            
        case .array, .dictionary:
            let data = Data(raw.utf8)
            let json = try JSONSerialization.jsonObject(with: data, options: [])
            guard let enc = json as? any Encodable else {
                throw SwiftUISyntaxError.invalidJSONLiteral(raw)
            }
            return enc
            
        case .regex, .colorLiteral, .imageLiteral, .fileLiteral, .memberAccess, .tuple, .nilLiteral:
            throw SwiftUISyntaxError.unsupportedSimpleLiteralDecoding(self)
        }
    }
}
