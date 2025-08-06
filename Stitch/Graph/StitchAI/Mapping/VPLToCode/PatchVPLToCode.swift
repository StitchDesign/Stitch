//
//  PatchVPLToCode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/1/25.
//

import SwiftUI

extension GraphState {
    @MainActor
    func createSwiftUICode(ignoreScript: Bool = false, usePortValueDescription: Bool = true) throws -> String {
        let graphEntity = self.createSchema()
        let aiGraph = try AIGraphData_V0.GraphData(from: graphEntity)
        
        let patchNodeDeclarations = try graphEntity
            .createBindingDeclarations(nodeIdsInTopologicalOrder: self.nodeIdsInTopologicalOrder,
                                       viewStatePatchConnections: aiGraph.viewStatePatchConnections)
            .patchNodeDeclarations
        
        let stateVarDeclarations = aiGraph.viewStatePatchConnections.keys.map { stateVarName in
            "@State var \(stateVarName): [PortValueDescription] = []"
        }
            .joined(separator: "\n\t")
        
        let allLayerEntities = graphEntity.nodes
            .compactMap { $0.layerNodeEntity }
        
        let layerEntitiesMap = allLayerEntities.reduce(into: [UUID: LayerNodeEntity]()) { result, layerNode in
            result.updateValue(layerNode, forKey: layerNode.id)
        }
        
        // Filter for just top layer entities in beginning
        let topLevelLayerEntities = allLayerEntities
            .filter { $0.layerGroupId == nil }
        
        let viewCode = try topLevelLayerEntities
            .createSwiftUICode(layerEntityMap: layerEntitiesMap)
        
        if ignoreScript {
            return viewCode
        }
        
        let script = """
struct ContentView: some View {
    \(stateVarDeclarations)

    var body: some View {
        \(viewCode)
    }

    func updateLayerInputs() {
        \(patchNodeDeclarations.joined(separator: "\n\t\t"))
    }
}
"""
        
        return script
    }
}
