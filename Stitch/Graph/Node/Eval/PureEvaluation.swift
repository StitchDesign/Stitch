//
//  PureEvaluation.swift
//  Stitch
//
//  Created by Christian J Clampitt on 1/30/23.
//

import Foundation
import StitchSchemaKit

// (node, state) -> node

// ALL SAME PATTERN: (PatchNode, T) -> PatchNode
typealias PureNode = (PatchNode) -> EvalResult
typealias PureGraphStepEval = (PatchNode, GraphStepState) -> EvalResult
typealias PureGraphEval = (PatchNode, GraphDelegate) -> EvalResult

enum PureEvals {
    case node(PureNode)
    case graphStep(PureGraphStepEval)
    case graph(PureGraphEval)

    @MainActor func runEvaluation(node: PatchNode) -> EvalResult {
        guard let graph = node.graphDelegate else {
            fatalErrorIfDebug()
            return .init()
        }
        
        switch self {
        case .node(let x):
            return x(node)
        case .graphStep(let x):
            let graphStep = graph.graphStepState
            return x(node, graphStep)
        case .graph(let x):
            return x(node, graph)
        }
    }
}
