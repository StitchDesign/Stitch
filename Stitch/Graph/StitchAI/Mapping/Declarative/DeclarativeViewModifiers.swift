//
//  DeclarativeViewModifiers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/25.
//

import SwiftUI
import SwiftSyntax
import SwiftParser
import StitchSchemaKit



protocol SwiftUIViewModifier {
    /// `nil` if the modifier can’t be represented (e.g. unsupported exotic overload).
    static func from(_ call: FunctionCallExprSyntax) -> Self?
    
    /// Stitch mapping — a modifier never introduces a new Layer, it only
    /// contributes `ValueOrEdge`s. Return `[]` if the modifier has no Stitch
    /// effect (e.g. `.showsIndicators`, `.clipped()`).
    var toStitch: [ValueOrEdge] { get }
}

// MARK: - Umbrella enum for all parsed modifiers
// If you add a new concrete modifier enum, register it here.
enum StitchViewModifier: Equatable {
    case scaleEffect(ScaleEffectModifier)
    case opacity(OpacityModifier)
    case frame(FrameModifier)
//    case position(PositionModifier)
//    case offset(OffsetModifier)
    // ✱ add more as they are implemented

    /// Aggregate Stitch inputs from the underlying modifier.
    var toStitch: [ValueOrEdge] {
        switch self {
        case .scaleEffect(let m): return m.toStitch
        case .opacity(let m):     return m.toStitch
        case .frame(let m):       return m.toStitch
//        case .position(let m):    return m.toStitch
//        case .offset(let m):      return m.toStitch
        }
    }
}

/// Temporary alias so older code that still uses `ViewModifierConstructor`
/// continues to compile. Remove once all call-sites are migrated.
typealias ViewModifierConstructor = StitchViewModifier

enum ScaleEffectModifier: Equatable, SwiftUIViewModifier {
    case uniform(Parameter<CGFloat>)
    case nonUniform(Parameter<CGSize>)
    
    static func from(_ call: FunctionCallExprSyntax) -> Self? {
        guard call.calledExpression.is(MemberAccessExprSyntax.self),
              call.calledExpression.description.hasSuffix("scaleEffect") else { return nil }

        if call.arguments.count == 1, call.arguments.first!.label == nil {
            // Might be CGFloat or CGSize
            let arg = call.arguments.first!
            if let size = arg.cgSizeLiteral {
                return .nonUniform(.literal(size))
            }
            if let num = arg.cgFloatValue {
                return .uniform(.literal(num))
            }
            // expression fallback
            return .uniform(.expression(arg.expression))
        }
        return nil           // ignore the anchor / anchorZ overload for brevity
    }
    
    var toStitch: [ValueOrEdge] {
        switch self {
        case .uniform(let p):
            return p.mapTo(.scale)
        case .nonUniform(let p):
            // decide whether you want two ports or one composite
            // TODO: MAPPING: how to handle compositeScale ? just grab the width or the height ?
            return p.mapTo(.scale)
        }
    }
}

struct OpacityModifier: Equatable, SwiftUIViewModifier {
    let value: Parameter<Double>
    
    static func from(_ call: FunctionCallExprSyntax) -> Self? {
        guard call.calledExpression.description.hasSuffix("opacity"),
              let first = call.arguments.first else { return nil }
        return .init(value: first.numberParam())
    }

    var toStitch: [ValueOrEdge] {
        value.mapTo(.opacity)
    }
}


enum FrameModifier: Equatable, SwiftUIViewModifier {
    
    case fixed(width:  Parameter<CGFloat?>,
               height: Parameter<CGFloat?>,
               alignment: Parameter<Alignment>)
    
    case range(minWidth:    Parameter<CGFloat?>,
               idealWidth:  Parameter<CGFloat?>,
               maxWidth:    Parameter<CGFloat?>,
               minHeight:   Parameter<CGFloat?>,
               idealHeight: Parameter<CGFloat?>,
               maxHeight:   Parameter<CGFloat?>,
               alignment:   Parameter<Alignment>)
    
    static func from(_ call: FunctionCallExprSyntax) -> Self? {
        nil
    }
    
    var toStitch: [ValueOrEdge] {
        []
    }
}


private extension Parameter {
    func mapTo(_ port: LayerInputPort) -> [ValueOrEdge] {
        switch self {
        case .literal(let v as CGFloat):
            return [ .value(.init(port, .number(v))) ]
        case .literal(let v as Double):
            return [ .value(.init(port, .number(v))) ]
        case .literal(let v as CGSize):
            return [ .value(.init(port, .size(.init(v)))) ]     // adjust if needed
        case .expression(let e):
            return [ .edge(e) ]
        default:
            return []   // for nil optionals
        }
    }
}

extension LabeledExprSyntax {
    func numberParam() -> Parameter<Double> {
        if let v = doubleLiteralValue { return .literal(v) }
        return .expression(expression)
    }
    
    // ---- Double / CGFloat literal --------------------------------------
    var doubleLiteralValue: Double? {
        if let f = expression.as(FloatLiteralExprSyntax.self) {
            return Double(f.literal.text)
        }
        if let i = expression.as(IntegerLiteralExprSyntax.self) {
            return Double(i.literal.text)
        }
        return nil
    }
    
    // ---- CGSize(width: …, height: …) literal ---------------------------
    var cgSizeLiteral: CGSize? {
        // Accept both `CGSize(width: w, height: h)` and `CGSize(w, h)`
        guard
            let call = expression.as(FunctionCallExprSyntax.self),
            call.calledExpression.as(DeclReferenceExprSyntax.self)?
                 .baseName.text == "CGSize"
        else { return nil }

        // Default param order if unlabeled is (width,height)
        var width:  CGFloat?
        var height: CGFloat?

        for (idx, arg) in call.arguments.enumerated() {
            let label = arg.label?.text
            if label == "width" || (label == nil && idx == 0) {
                width = arg.cgFloatValue
            } else if label == "height" || (label == nil && idx == 1) {
                height = arg.cgFloatValue
            }
        }
        if let w = width, let h = height { return CGSize(width: w, height: h) }
        return nil
    }
}
