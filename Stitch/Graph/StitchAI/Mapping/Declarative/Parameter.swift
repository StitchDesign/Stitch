//
//  Parameter.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/25.
//

import SwiftUI
import SwiftSyntax
import SwiftParser


// MARK: - Parameter wrapper: literal vs. arbitrary expression ---------

/// A constructor argument that was either a compile‑time literal (`"logo"`,
/// `.center`, `12`) or an arbitrary Swift expression (`myGap`, `foo()`, etc.).
//enum Parameter<Value: Equatable>: Equatable {
//    case literal(Value)
//    case expression(ExprSyntax)
//
//    /// Convenience for pattern‑matching in `toStitch`.
//    var literal: Value? {
//        if case .literal(let v) = self { return v }
//        return nil
//    }
//}

//enum ValueOrEdge: Equatable {
//    case value(CustomInputValue)
//    case edge(ExprSyntax)
//}

struct ASTCustomInputValue: Equatable, Hashable {
    let input: CurrentStep.LayerInputPort
    let values: [CurrentStep.PortValue]
    
//    init(_ input: LayerInputPort,  _ value: PortValue) {
//        self.input = input
//        self.value = value
//    }
}
