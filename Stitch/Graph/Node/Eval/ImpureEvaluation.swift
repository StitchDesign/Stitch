//
//  ImpureEvaluation.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/23.
//

import Foundation
import StitchSchemaKit

// produces new outputs,
// but may also update inputs, create a side effect, cause node to run again, etc.

//typealias ImpureNodeEval = (PatchNode) -> ImpureEvalResult
//
//// SAME PATTERN: (PatchNode, T) -> ImpureEvalResult
//typealias ImpureGraphEval = (PatchNode, GraphDelegate) -> ImpureEvalResult
//typealias ImpureGraphStepEval = (PatchNode, GraphStepState) -> ImpureEvalResult
//
//// (PatchNode, T, K, J) -> ImpureEvalResult
//typealias ImpureGraphStateAndGraphStep = (PatchNode, GraphDelegate, GraphStepState) -> ImpureEvalResult
//
//enum ImpureEvals {
//    case node(ImpureNodeEval)
//    case graph(ImpureGraphEval)
//    case graphStep(ImpureGraphStepEval)
//    case graphAndGraphStep(ImpureGraphStateAndGraphStep)
//
//    @MainActor
//    func runEvaluation(node: PatchNode) -> ImpureEvalResult {
//        guard let graphState = node.graphDelegate else {
//            fatalErrorIfDebug()
//            return .init(outputsValues: node.defaultOutputsList)
//        }
//        
//        let graphStepState = graphState.graphStepState
//        
//        switch self {
//        case .node(let impureNodeEval):
//            return impureNodeEval(node)
//        case .graph(let impureGraphEval):
//            return impureGraphEval(node, graphState)
//        case .graphStep(let impureGraphStepEval):
//            return impureGraphStepEval(node, graphStepState)
//        case .graphAndGraphStep(let impureMediaAndGraphAndStepAndComputed):
//            return impureMediaAndGraphAndStepAndComputed(node,
//                                                         graphState,
//                                                         graphStepState)
//        }
//    }
//}

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
