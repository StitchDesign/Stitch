//
//  AIGraphBuilderSystemPromptGenerator.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/18/25.
//

import SwiftUI

extension StitchAIManager {
    @MainActor
    static func stitchAIDataGlossarySystemPrompt(graph: GraphState) throws -> String {
        let excludedPatches: Set<Patch> = Set([
            .scrollInteraction, .dragInteraction, .pressInteraction
        ])
        
        let patchDescriptions = AIGraphData_V0.Patch.allAiDescriptions
            .filter { description in
                let isExcludedNode = excludedPatches.contains(where: { description.nodeKind.contains($0.aiDisplayTitle) })
                
                return !isExcludedNode
            }
        
        let layerDescriptions = AIGraphData_V0.Layer.allAiDescriptions
        
        let nodePortDescriptions = try NodeSection.getAllAIDescriptions(graph: graph,
                                                                        excludedPatches: excludedPatches)
        
        return """
"""
    }
}
