//
//  GraphFlow.swift
//  Stitch
//
//  Created by cjc on 1/6/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine

extension GraphState {
    /// Gets all node IDs except for those in groups.
    @MainActor
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
