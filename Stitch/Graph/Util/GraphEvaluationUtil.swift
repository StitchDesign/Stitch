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
        self.runGraphAndUpdateUI(from: self.allNodesToCalculate)
    }
        
    @MainActor
    func calculateFullGraph() {
        // Overwrites previous ops
        self.setNodesForNextGraphStep(self.allNodesToCalculate)
    }
}

extension NodeViewModel {
    @MainActor
    func scheduleForNextGraphStep() {
        // TODO: Can this ever be called when we don't have a graph? It doesn't make sense
        self.graphDelegate?.scheduleForNextGraphStep(self.id)
    }
}
