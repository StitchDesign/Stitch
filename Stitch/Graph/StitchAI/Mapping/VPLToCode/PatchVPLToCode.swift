//
//  PatchVPLToCode.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/1/25.
//

import SwiftUI

extension GraphState {
    @MainActor
    func createSwiftUICode() throws -> String {
        let graphEntity = self.createSchema()
        let aiGraph = try AIGraphData_V0.GraphData(from: graphEntity)
        
        // TODO: check if needed
        var idMap = [String : UUID]()
        
        let patchNodeDeclarations = try graphEntity
            .createBindingDeclarations(nodeIdsInTopologicalOrder: self.nodeIdsInTopologicalOrder,
                                       viewStatePatchConnections: aiGraph.viewStatePatchConnections)
            .patchNodeDeclarations
        
        let stateVarDeclarations = aiGraph.viewStatePatchConnections.keys.map { stateVarName in
            "@State var \(stateVarName): [PortValueDescription] = []"
        }
            .joined(separator: "\n\t")
        
        let syntaxes = try aiGraph.layer_data_list.compactMap { layerData in
            try layerDataToStrictSyntaxView(layerData, idMap: &idMap)
        }
        
        // Generate complete SwiftUI code from StrictSyntaxView
        let viewCode = syntaxes.map { strictSyntaxView in
            strictSyntaxView.toSwiftUICode()
        }.joined(separator: "\n\n\t\t")
        
        
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
