//
//  StitchToPatchData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/31/25.
//

import SwiftSyntax
import SwiftParser
import SwiftSyntaxBuilder
import SwiftUI

extension GraphEntity {
    func createBindingDeclarations(nodeIdsInTopologicalOrder: [UUID]) throws -> String {
        // Maps node IDs to a new var name
        var varNameMap: [UUID: String] = [:]
        
        let patchNodeEntityDict = self.nodes.reduce(into: [UUID: PatchNodeEntity]()) { result, nodeEntity in
            if let patchNodeEntity = nodeEntity.nodeTypeEntity.patchNodeEntity {
                result.updateValue(patchNodeEntity, forKey: nodeEntity.id)
            }
        }
        
        let patchNodeDeclarations = try nodeIdsInTopologicalOrder.compactMap { nodeId -> String? in
            guard let patchNodeEntity = patchNodeEntityDict.get(nodeId) else {
                fatalErrorIfDebug()
                return nil
            }
            
            let varName = "\(patchNodeEntity.patch.rawValue)_\(nodeId.uuidString)"
            
            let args: [String] = try patchNodeEntity.inputs.map { inputData in
                switch inputData.portData {
                case .values(let values):
                    guard let firstValue = values.first else {
                        fatalError()
                    }
                    
                    let valueDesc = PrintablePortValueDescription(firstValue)
                    let string = try valueDesc.encodeToString()
                    return string
                    
                case .upstreamConnection(let upstream):
                    // Variable name should already exist given topological order, otherwise its a cycle case which we should ignore
                    guard let upstreamVarName = varNameMap.get(upstream.nodeId),
                          let portId = upstream.portId else {
                        throw SwiftUISyntaxError.upstreamVarNameNotFound(upstream)
                    }
                    
                    return "\(upstreamVarName)[\(portId)]"
                }
            }
            
            let patchDeclaration = """
                let \(varName) = NATIVE_STITCH_PATCH_FUNCTIONS["\(patchNodeEntity.patch.aiNodeDescription)"](\(args.joined(separator: ",")))
                """
            
            varNameMap.updateValue(varName, forKey: nodeId)
            return patchDeclaration
        }
        
        // TODO: find all layer inputs with connections, get the upstream patch node id, and make assignment
        
        return patchNodeDeclarations.joined(separator: "\n")
    }
}
