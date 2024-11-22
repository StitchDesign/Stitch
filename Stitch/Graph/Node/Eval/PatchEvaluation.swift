//
//  PatchEvaluation.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine

struct EvalResult: NodeEvalResult, Sendable {
    typealias Node = NodeViewModel

    // TODO: clean up properties below?
    var willEvalAgain: Bool {
        get {
            self.runAgain
        }
        set(newValue) {
            self.runAgain = newValue
        }
    }
    
    var mustEvalAllDownstreamNodes: Bool {
        get {
            self.didMediaObjectChange
        }
        set(newValue) {
            self.didMediaObjectChange = newValue
        }
    }
    
    
    var outputsValues: PortValuesList
    var effects = SideEffects()
    var runAgain = false

    // Determines if media objects changed in a manner which should trigger downstream nodes
    var didMediaObjectChange = false
}

extension EvalResult {
    /// Failure state initializer.
    init() {
        self.outputsValues = []
    }
}

enum EvaluationStyle {
    case pure(PureEvals),
         impure(ImpureEvals)
}
