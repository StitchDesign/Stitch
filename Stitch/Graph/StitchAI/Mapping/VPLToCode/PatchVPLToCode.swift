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
        
        let patchData = try graphEntity
            .createBindingDeclarations(nodeIdsInTopologicalOrder: self.nodeIdsInTopologicalOrder,
                                       viewStatePatchConnections: aiGraph.viewStatePatchConnections)
        
        let patchNodeDeclarations = patchData.patchNodeDeclarations
        
        let stateVarDeclarations = aiGraph.viewStatePatchConnections.keys.map { stateVarName in
            "@State var \(stateVarName): [PortValueDescription] = []"
        }
            .joined(separator: "\n\t")
        
        // log("createSwiftUICode: stateVarDeclarations: \(stateVarDeclarations)")
        
        let allLayerEntities = graphEntity.nodes
            .compactMap { $0.layerNodeEntity }
        
        // log("createSwiftUICode: allLayerEntities: \(allLayerEntities)")
        
        let orderedLayerEntities = graphEntity.orderedSidebarLayers
            .flattenedIds
            .compactMap { id -> LayerNodeEntity? in
                guard let layerEntity = self.nodes.get(id)?.layerNodeViewModel else {
                    fatalErrorIfDebug()
                    return nil
                }
                
                return layerEntity.createSchema()
            }
        
        // Filter for just top layer entities in beginning
        let topLevelLayerEntities = allLayerEntities
            .filter { $0.layerGroupId == nil }
        
        // log("createSwiftUICode: topLevelLayerEntities: \(topLevelLayerEntities)")
        
        // Maps upstream patch node ID to a variable name
        let varNameIdMap = aiGraph.viewStatePatchConnections.reduce(into: [UUID: String]()) { result, data in
            let (variableName, nodeIndexCoordiante) = data
            
            guard let nodeId = UUID(nodeIndexCoordiante.node_id) else {
                fatalErrorIfDebug()
                return
            }
            
            result.updateValue(variableName, forKey: nodeId)
        }
        
        // log("createSwiftUICode: varNameIdMap: \(varNameIdMap)")
        
        let viewCode = try topLevelLayerEntities
            .createSwiftUICode(orderedLayerEntities: orderedLayerEntities,
                               varIdNameMap: varNameIdMap)
        
        if ignoreScript {
            return viewCode
        }
        
        // Create js nodes script
        let jsNodesScript = patchData.jsNodeFns.map { jsNodeData in
            """
            static func fn_\(jsNodeData.key)(_ inputs: [[PortValueDescription]]) -> [[PortValueDescription]] {
                \(jsNodeData.value)
            }
            """
        }
            .joined(separator: "\n\n")
        
        let script = """
struct ContentView: some View {
    \(stateVarDeclarations)

    var body: some View {
        \(viewCode)
    }

    func updateLayerInputs() {
        \(patchNodeDeclarations.joined(separator: "\n\t\t"))
    }

    \(jsNodesScript)
}
"""
        
        return script
    }
}
