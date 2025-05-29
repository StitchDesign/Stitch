//
//  StepValidation.swift
//  Stitch
//
//  Created by Christian J Clampitt on 5/24/25.
//

import Foundation

typealias DepthMap = [UUID: Int]

extension Array where Element == any StepActionable {
    // Note: just some obvious validations; NOT a full validation; we can still e.g. create a connection from an output that doesn't exist etc.
    // nil = valid
    func validateLLMSteps() -> StitchAIStepHandlingError? {
                
        // Need to update this *as we go*, so that we can confirm that e.g. connectNodes came after we created at least two different nodes
        var createdNodes = [NodeId: PatchOrLayer]()
        
        for step in self {
            switch step.validate(createdNodes: createdNodes) {
            case .failure(let validationError):
                return validationError
            case .success(let updatedCreatedNodes):
                createdNodes = updatedCreatedNodes
            }
        } // for step in self
        
        let (depthMap, hasCycle) = self.calculateAINodesAdjacency()
        if hasCycle {
            return .actionValidationError("Had cycle; cycles currently not supported")
        } else if depthMap.isNotDefined {
            return .actionValidationError("Could not topologically order the graph")
        } else {
            return nil
        }
    }
    
    func calculateAINodesAdjacency() -> (depthMap: DepthMap?,
                                         hasCycle: Bool) {
        let adjacency = AdjacencyCalculator()
        self.forEach {
            if let connectNodesAction = $0 as? StepActionConnectionAdded {
                adjacency.addEdge(from: connectNodesAction.fromNodeId, to: connectNodesAction.toNodeId)
            }
        }
        
        let (depthMap, hasCycle) = adjacency.computeDepth()
        
        if var depthMap = depthMap, !hasCycle {
            // If we did not have a cycle, also add those nodes which did not have a connection;
            // Node without connection = node with depth level 0
            self.nodesCreatedByLLMActions().forEach {
                if !depthMap.get($0).isDefined {
                    depthMap.updateValue(0, forKey: $0)
                }
            }
            return (depthMap, hasCycle)
            
        } else {
            return (depthMap, hasCycle)
        }
    }
}


