//
//  Parameter.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/25.
//

import SwiftUI
import SwiftSyntax
import SwiftParser

//struct ASTCustomInputValue: Equatable, Hashable {
//    let input: CurrentAIGraphData.LayerInputPort
//    let value: LayerPortDerivationType
//}

typealias ASTCustomInputValue = LayerPortDerivation

extension LayerPortDerivation {
    // TODO: remove this init
    init(id: NodeId,
         input: LayerInputPort,
         value: CurrentAIGraphData.PortValue) {
        self.init(input: input,
                  value: value)
    }
    
    init(input: LayerInputPort,
         value: CurrentAIGraphData.PortValue) {
        self = .init(coordinate: .init(layerInput: input,
                                       portType: .packed),
                     inputData: .value(.init(value)))
    }
    
    init(input: LayerInputPort,
         inputData: LayerPortDerivationType) {
        self = .init(coordinate: .init(layerInput: input,
                                       portType: .packed),
                     inputData: inputData)
    }
}

extension Array where Element == LayerPortDerivation {
    init(_ portTypes: [LayerPortDerivationType], input: LayerInputPort) {
        self = portTypes.map {
            LayerPortDerivation.init(input: input,
                                     inputData: $0)
        }
    }
}

/// A constructor argument that was either a compile‑time literal (`"logo"`,
 /// `.center`, `12`) or an arbitrary Swift expression (`myGap`, `foo()`, etc.).
 enum Parameter<Value: Equatable>: Equatable {
     case literal(Value)
     case expression(ExprSyntax)

     /// Convenience for pattern‑matching in `toStitch`.
     var literal: Value? {
         if case .literal(let v) = self { return v }
         return nil
     }
 }
