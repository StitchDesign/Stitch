//
//  PulseEvaluationHelpers.swift
//  Stitch
//
//  Created by Christian J Clampitt on 10/5/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

func pulseEvalUpdate(_ opValues: PortValuesList,
                     _ opOutputs: PortValuesList,
                     _ operation: @escaping PulseOperationT) -> ImpureEvalResult {
    
    loopedEval(inputsValues: opValues,
               outputsValues: opOutputs) { values, _ in
        operation(values)
    }
               .toImpureEvalResult()
}

typealias PulseOperationT = (PortValues) -> ImpureEvalOpResult

// FOR A GIVEN INDEX IN A LOOP:

// All the possible new values a pulse-receiving and/or -emitting node eval can create
// MARK: legacy here, using typealias to keep old evals alive
typealias PulseOpResultT = ImpureEvalOpResult

extension PulseOpResultT {
    // convenience constructor
    init(_ value: PortValue,
         effect: Effect? = nil,
         runAgain: Bool = false) {

        self.outputs = [value]
        self.willRunAgain = runAgain
    }

    init(_ values: PortValues,
         effect: Effect? = nil,
         runAgain: Bool = false) {

        self.outputs = values
        self.willRunAgain = runAgain
    }
}
