//
//  EvaluationHelpers.swift
//  Stitch
//
//  Created by cjc on 2/12/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI

// an evalution that only produces new outputs
typealias OutputsOnlyPureEval = (PortValuesList, PortValuesList) -> PortValuesList

// -- MARK: WRAPPERS AROUND EVAL METHODS

// TODO: come up with an abstraction here that combines these evals etc.

@MainActor
func outputsOnlyEval(_ eval: @escaping OutputsOnlyPureEval) -> PureNode {
    { (node: PatchNode) -> EvalResult in
            .init(outputsValues: eval(node.inputs,
                                      node.outputs))
    }
}


typealias OutputsAndNodeTypePureEval = (PortValuesList, PortValuesList, UserVisibleType?) -> PortValuesList

@MainActor
func outputsOnlyEval(_ eval: @escaping OutputsAndNodeTypePureEval) -> PureNode {
    { (node: PatchNode) -> EvalResult in
            .init(outputsValues: eval(
                node.inputs,
                node.outputs,
                node.userVisibleType))
    }
}


typealias OutputsOnlyGraphStateEval = (PatchNode, GraphState) -> PortValuesList

func outputsOnlyGraphStateEval(_ eval: @escaping OutputsOnlyGraphStateEval) -> PureGraphEval {

    return { (node: PatchNode, graphState: GraphState) -> EvalResult in
        let newOutputValues: PortValuesList = eval(node, graphState)

        // update the outputs
        return .init(outputsValues: newOutputValues)
    }
}

typealias OutputsOnlyArithmeticPureEval = (PortValuesList, ArithmeticNodeType) -> PortValuesList
// typealias OutputsOnlyMathPureEval = (PortValuesList, MathNodeType) -> PortValuesList
// typealias OutputsOnlyComparablePureEval = (PortValuesList, ComparableNodeType) -> PortValuesList

@MainActor
func outputsOnlyEval(_ eval: @escaping OutputsOnlyArithmeticPureEval,
                     outputCountChangeAllowed: Bool = false) -> PureNode {
    { (node: PatchNode) -> EvalResult in

        guard let patchNode = node.patchNode,
              let evalKind = patchNode.asArithmeticEval else {
            log("OutputsOnlyArithmeticPureEval: Could not eval node")
            return .init(outputsValues: node.outputs)
        }

        let newOutputValues: PortValuesList = eval(
            node.inputs,
            evalKind)

        return .init(outputsValues: newOutputValues)
    }
}

// don't need to be defining this everytime in each eval method...
@MainActor
func singeOutputEvalResult(_ op: Operation,
                           _ inputs: PortValuesList) -> PortValuesList {
    resultsMaker(inputs)(op)
}
