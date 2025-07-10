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
