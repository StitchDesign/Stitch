//
//  SyntaxViewConstructorUtils.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/10/25.
//

import Foundation
import SwiftUI
import UIKit
import SwiftSyntax


extension AttributedString {
    /// Returns only the textual content (attributes are discarded).
    var plainText: String { self.description }   // `.description` flattens to String
}

extension LocalizedStringKey {
    /// Best‑effort: resolves through the app’s main bundle; falls back to the key itself.
    var resolved: String {
        let keyString = String(describing: self)   // mirrors what the dev wrote
        return NSLocalizedString(keyString,
                                 bundle: .main,
                                 value: keyString,
                                 comment: "")
    }
}

// ── Alignment → Anchoring helpers ───────────────────────────────────────

extension VerticalAlignment {
    var toAnchoring: Anchoring {
        switch self {
        case .top:               return .topCenter
        case .bottom:            return .bottomCenter
        case .firstTextBaseline: return .topCenter       // best-effort
        case .lastTextBaseline:  return .bottomCenter    // best-effort
        default:                 return .centerCenter    // .center
        }
    }
}

extension HorizontalAlignment {
    var toAnchoring: Anchoring {
        switch self {
        case .leading:  return .centerLeft
        case .trailing: return .centerRight
        default:        return .centerCenter             // .center
        }
    }
}



// MARK: - UnitPoint to Anchoring mapping
extension UnitPoint {
    var toAnchoring: Anchoring {
        switch (x, y) {
        case (0, 0):   return .topLeft
        case (0.5, 0): return .topCenter
        case (1, 0):   return .topRight
        case (0, 0.5): return .centerLeft
        case (0.5, 0.5): return .centerCenter
        case (1, 0.5): return .centerRight
        case (0, 1):   return .bottomLeft
        case (0.5, 1): return .bottomCenter
        case (1, 1):   return .bottomRight
        default:       return .centerCenter
        }
    }
}

// ── UnitPoint, Angle, Color helpers ─────────────────────────────────────
extension LabeledExprSyntax {
    
    /// `.center` → UnitPoint.center, etc.
    var unitPointLiteral: UnitPoint? {
        guard let name = expression.as(MemberAccessExprSyntax.self)?
            .declName.baseName.text else { return nil }
        return switch name {
        case "center":  .center
        case "top":     .top
        case "bottom":  .bottom
        case "leading": .leading
        case "trailing":.trailing
        case "topLeading":    .topLeading
        case "topTrailing":   .topTrailing
        case "bottomLeading": .bottomLeading
        case "bottomTrailing":.bottomTrailing
        default: nil
        }
    }
    
    /// `Angle(degrees: 45)` → 45
    var angleDegreesLiteral: CGFloat? {
        guard
            let call = expression.as(FunctionCallExprSyntax.self),
            call.calledExpression.as(DeclReferenceExprSyntax.self)?
                .baseName.text == "Angle",
            call.arguments.first?.label?.text == "degrees"
        else { return nil }
        
        if let floatLit = call.arguments.first?.expression
            .as(FloatLiteralExprSyntax.self) {
            return CGFloat(Double(floatLit.literal.text) ?? 0)
        }
        if let intLit = call.arguments.first?.expression
            .as(IntegerLiteralExprSyntax.self) {
            return CGFloat(Double(intLit.literal.text) ?? 0)
        }
        return nil
    }
    
    /// `[Color.red, Color.blue]` → `[Color.red, Color.blue]`
    var colorArrayLiteral: [Color]? {
        guard let array = expression.as(ArrayExprSyntax.self) else { return nil }
        var result: [Color] = []
        for elt in array.elements {
            guard let member = elt.expression.as(MemberAccessExprSyntax.self),
                  member.base?.description.trimmingCharacters(in: .whitespacesAndNewlines) == "Color"
            else { return nil }
            switch member.declName.baseName.text {
            case "red":    result.append(.red)
            case "blue":   result.append(.blue)
            case "green":  result.append(.green)
            case "yellow": result.append(.yellow)
            case "purple": result.append(.purple)
            case "pink":   result.append(.pink)
            case "orange": result.append(.orange)
            case "black":  result.append(.black)
            case "white":  result.append(.white)
            case "gray":   result.append(.gray)
            default:       return nil
            }
        }
        return result
    }
}


extension Alignment {
    var toAnchoring: Anchoring {
        switch self {
        case .topLeading:     return .topLeft
        case .top:            return .topCenter
        case .topTrailing:    return .topRight
        case .leading:        return .centerLeft
        case .center:         return .centerCenter
        case .trailing:       return .centerRight
        case .bottomLeading:  return .bottomLeft
        case .bottom:         return .bottomCenter
        case .bottomTrailing: return .bottomRight
        default:              return .centerCenter
        }
    }
}


// MARK: Literal‑array helper  (generic)
// ---------------------------------------------------------------------
/// If the expression is *exactly* an array literal and every element can
/// be converted by `itemMapper`, return the mapped array. Otherwise `nil`.
extension ExprSyntax {
    func literalArray<Element>(_ itemMapper: (ExprSyntax) -> Element?) -> [Element]? {
        guard let arr = self.as(ArrayExprSyntax.self) else { return nil }
        var out: [Element] = []
        for elem in arr.elements {
            guard let mapped = itemMapper(elem.expression) else { return nil }
            out.append(mapped)
        }
        return out
    }
}
/// Maps `.green` → Color.green  (relies on Color.init(_:))
extension ExprSyntax {
    var colorLiteral: Color? {
        guard let mem = self.as(MemberAccessExprSyntax.self) else { return nil }
        return Color.fromSystemName(mem.declName.baseName.text)
    }
    var axisMember: Axis.Set.Element? {
        guard let mem = self.as(MemberAccessExprSyntax.self) else { return nil }
        switch mem.declName.baseName.text {
        case "horizontal": return .horizontal
        case "vertical":   return .vertical
        default:           return nil
        }
    }
}
// MARK: Axis‑Set literal helper  (.horizontal / .vertical / [.horizontal, .vertical])
extension ExprSyntax {
    /// If the expression can be evaluated at parse time to a concrete Axis.Set,
    /// return it; otherwise return `nil`.
    func axisSetLiteral() -> Axis.Set? {
        // 1) Single member access: `.horizontal`, `.vertical`, `.all`
        if let ma = self.as(MemberAccessExprSyntax.self) {
            switch ma.declName.baseName.text {
            case "horizontal": return .horizontal
            case "vertical":   return .vertical
            case "all":        return [.horizontal, .vertical]
            default: break
            }
        }
        
        // 2) Array literal: `[.horizontal, .vertical]`
        if let elems = self.literalArray({ $0.axisMember }) {
            return Axis.Set(elems)
        }
        return nil
    }
}

// ── Tiny extraction helpers for alignment / spacing literals ─────────────
extension SyntaxViewModifierArgumentType {
    var alignmentLiteral: Alignment? {
        switch self {
        case .memberAccess(let member):
            guard let member = member.base else { return nil }
            switch member {
            case "topLeading":     return .topLeading
            case "top":            return .top
            case "topTrailing":    return .topTrailing
            case "leading":        return .leading
            case "center":         return .center
            case "trailing":       return .trailing
            case "bottomLeading":  return .bottomLeading
            case "bottom":         return .bottom
            case "bottomTrailing": return .bottomTrailing
            default: return nil
        }
        default:
            return nil
    }
    
    var cgFloatValue: CGFloat? {
        switch self {
        case .simple(let data):
            switch data.syntaxKind {
            case .float, .integer:
                return CGFloat(Double(data.value) ?? 0)
            default:
                return nil
            }
        default:
            return nil
        }
    }
    
    // New helper: vertical alignment literal
    var vertAlignLiteral: VerticalAlignment? {
        switch self {
        case .memberAccess(let syntaxViewMemberAccess):
            if let ident = syntaxViewMemberAccess.base {
                switch ident {
                case "top": return .top
                case "bottom": return .bottom
                case "firstTextBaseline": return .firstTextBaseline
                case "lastTextBaseline": return .lastTextBaseline
                case "center": return .center
                default: return nil
                }
            }
            
        default:
            return nil
        }
    }
    
    // New helper: horizontal alignment literal
    var horizAlignLiteral: HorizontalAlignment? {
        if let ident = expression.as(MemberAccessExprSyntax.self)?
            .declName.baseName.text {
            switch ident {
            case "leading": return .leading
            case "trailing": return .trailing
            case "center": return .center
            default: return nil
            }
        }
        return nil
    }
    
//    func asParameterString() -> Parameter<String> {
//        if let lit = expression.as(StringLiteralExprSyntax.self) {
//            return .literal(lit.decoded())
//        }
//        return .expression(expression)
//    }
//    
//    func asParameterCGFloat() -> Parameter<CGFloat> {
//        if let lit = cgFloatValue {
//            return .literal(lit)
//        }
//        return .expression(expression)
//    }
    
    func asParameterCGSize() -> Parameter<CGSize> {
        if let tuple = expression.as(TupleExprSyntax.self),
           let wLit = tuple.elements.first?.expression.as(FloatLiteralExprSyntax.self),
           let hLit = tuple.elements[safe: 1]?.expression.as(FloatLiteralExprSyntax.self),
           let w = Double(wLit.literal.text),
           let h = Double(hLit.literal.text) {
            return .literal(CGSize(width: w, height: h))
        }
        return .expression(expression)
    }
    
    func asParameterAxisSet() -> Parameter<Axis.Set> {
        if let ident = expression.as(MemberAccessExprSyntax.self)?
            .declName.baseName.text {
            switch ident {
            case "vertical":   return .literal(.vertical)
            case "horizontal": return .literal(.horizontal)
            default: break
            }
        }
        return .expression(expression)
    }
    
    func asParameterBool() -> Parameter<Bool> {
        if let bool = expression.as(BooleanLiteralExprSyntax.self) {
            return .literal(bool.literal.text == "true")
        }
        return .expression(expression)
    }
}

extension Parameter where Value: CustomStringConvertible {
    /// Fragment suitable for regenerating Swift source.
    var swiftFragment: String {
        switch self {
        case .literal(let v):    return String(describing: v)
        case .expression(let e): return e.description
        }
    }
}

extension ExprSyntax {
    /// If this expression is `.constant("string")` return the literal string.
    /// Otherwise return `nil`.
    func stringLiteralFromConstantBinding() -> String? {
        guard
            let call = self.as(FunctionCallExprSyntax.self),
            let baseName = call.calledExpression.as(MemberAccessExprSyntax.self)?
                .declName.baseName.text ?? call.calledExpression
                .as(DeclReferenceExprSyntax.self)?
                .baseName.text,
            baseName == "constant",
            let first = call.arguments.first,
            let lit   = first.expression.as(StringLiteralExprSyntax.self)
        else { return nil }
        
        return lit.decoded()
    }
}
