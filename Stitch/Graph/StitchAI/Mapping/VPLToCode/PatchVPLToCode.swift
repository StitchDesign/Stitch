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
        let layerViewEvents = aiGraph.layer_data_list.getAllViewEvents()
        
        // Patches that connect to layers
        let patchStateVars = Array(aiGraph.viewStatePatchConnections.keys)
        
        // Interaction data updated from gesture callbacks
        let interactionStateVars = layerViewEvents.map { $0.mutatedStateVar }
        
        let allStateVarNames = patchStateVars + interactionStateVars
        let stateVarDeclarations = allStateVarNames.map { stateVarName in
            "@State var \(stateVarName): [PortValueDescription] = []"
        }
            .joined(separator: "\n")
            .indentLines()

        // log("createSwiftUICode: stateVarDeclarations: \(stateVarDeclarations)")
        
        let allLayerEntities = graphEntity.nodes
            .compactMap { $0.layerNodeEntity }
        
        // log("createSwiftUICode: allLayerEntities: \(allLayerEntities)")
        
        let orderedLayerEntities = graphEntity.orderedSidebarLayers
            .createOrderedLayersForCodeGen(nodes: self.nodes)
        
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
            \(jsNodeData.value.indentLines())
            }
            """
        }
            .joined(separator: "\n\n")
        
        let innerStructContents = """
        \(stateVarDeclarations)

        var body: some View {
        \(viewCode.indentLines(n: 2))
        }

        func updateLayerInputs() {
        \(patchNodeDeclarations.joined(separator: "\n").indentLines())
        }

        \(jsNodesScript)
        """
        
        let script = """
        struct ContentView: View {
        \(innerStructContents.indentLines())
        }
        """
        
        return script
    }
}

extension Array where Element == SidebarLayerData {
    /// Takes into consideration `ZStack`'s for reversing items when appropriate
    @MainActor
    func createOrderedLayersForCodeGen(nodes: [UUID : NodeViewModel]) -> [LayerNodeEntity] {
        self.flatMap { sidebarData -> [LayerNodeEntity] in
            guard let layerEntity = nodes.get(sidebarData.id)?.layerNodeViewModel else {
                fatalErrorIfDebug()
                return []
            }
            
            let orientationValue = layerEntity.orientationPort.values.first?.getOrientation ?? .defaultOrientation
            let isThisParentUnordered = layerEntity.isGroupLayer && orientationValue == .none
            
            // Reverse children if code to be created is for `ZStack`.
            let children = isThisParentUnordered ? sidebarData.children?.reversed() : sidebarData.children
            
            return [layerEntity.createSchema()] + (children?.createOrderedLayersForCodeGen(nodes: nodes) ?? [])
        }
    }
}
