//
//  ImpureEvaluation.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/23.
//

import Foundation
import StitchSchemaKit

// TODO: tech debt to remove ImpureEvalResult
typealias ImpureEvalResult = EvalResult

extension ImpureEvalResult {

    // If we have no change in the node eval,
    // e.g. because interaction node had no layer assigned,
    // then return the node's existing outputs.

    // If existing outputs are empty, we likely should return default outputs.
    @MainActor
    static func noChange(_ node: PatchNode,
                         defaultOutputsValues: PortValuesList? = nil) -> ImpureEvalResult {
        #if DEV_DEBUG
        //        log("ImpureEvalResult: noChange: evaluating \(node.id) produced no change")
        #endif
        if node.outputs.isEmpty {
            #if DEV_DEBUG
            //            log("ImpureEvalResult: noChange: will use default outputs")
            #endif
            if let values = defaultOutputsValues {
                return .init(outputsValues: values)
            }
        }

        return .init(outputsValues: node.outputs)
    }
}
