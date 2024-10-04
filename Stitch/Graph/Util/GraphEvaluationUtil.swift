//
//  GraphFlow.swift
//  prototype
//
//  Created by cjc on 1/6/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine

extension GraphState {
    /// Gets all node IDs except for those in groups.
    var allNodesToCalculate: NodeIdSet {
        self.nodes.values
            .compactMap {
                // Ignore group nodes
                guard $0.nodeType.groupNode == nil else {
                    return nil
                }
                
                return $0.id
            }
            .toSet
    }
    
    @MainActor
    func initializeGraphComputation() {
        self.calculate(from: self.allNodesToCalculate)
    }
        
    @MainActor
    func calculateFullGraph() {
        // Overwrites previous ops
        self.setNodesForNextGraphStep(self.allNodesToCalculate)
    }
}

extension NodeViewModel {
    @MainActor
    func calculate() {
        self.graphDelegate?.calculate(self.id)
    }
}

extension EvaluationStyle {
    @MainActor
    func runEvaluation(node: NodeViewModel) -> EvalResult {

        switch self {

        case .pure(let pureEval):
            return pureEval
                .runEvaluation(node: node)

        case .impure(let impureEval):
            return impureEval
                .runEvaluation(node: node)
                .toEvalResult()
        }
    }
}

// Recalculates graph from a specific node
struct RecalculateGraphFromNode: GraphEvent {
    let nodeId: NodeId

    func handle(state: GraphState) {
        state.calculate(nodeId)
    }
}
