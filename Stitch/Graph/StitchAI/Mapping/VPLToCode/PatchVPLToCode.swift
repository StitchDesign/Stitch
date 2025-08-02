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
        
        let patchNodeDeclarations = try graphEntity.createBindingDeclarations(nodeIdsInTopologicalOrder: self.nodeIdsInTopologicalOrder)
            .patchNodeDeclarations
        
        // TODO: need layer data
        
        let script = """
func updateLayerInputs() {
    \(patchNodeDeclarations.joined(separator: "\n\t"))
}
"""
        
        return script
    }
}
