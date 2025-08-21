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

struct StitchPatchCodeConversionResult {
    let patchNodeDeclarations: [String]
    let jsNodeFns: [String: String]
    let varNameIdMap: [String : String]
}

extension GraphEntity {
    func createBindingDeclarations(nodeIdsInTopologicalOrder: [UUID],
                                   viewStatePatchConnections: [String : AIGraphData_V0.NodeIndexedCoordinate]) throws -> StitchPatchCodeConversionResult {
        // Maps node IDs to a new var name
        var varIdNameMap: [UUID: String] = [:]
        
        let patchNodeEntityDict = self.nodes.reduce(into: [UUID: PatchNodeEntity]()) { result, nodeEntity in
            if let patchNodeEntity = nodeEntity.nodeTypeEntity.patchNodeEntity {
                result.updateValue(patchNodeEntity, forKey: nodeEntity.id)
            }
        }
        
        let patchNodeDeclarations = try nodeIdsInTopologicalOrder.compactMap { nodeId -> String? in
            guard let patchNodeEntity = patchNodeEntityDict.get(nodeId) else {
                // Layer node, return nil
                return nil
            }
            
            let isJSNode = patchNodeEntity.patch == .javascript
            let varName = patchNodeEntity.patch.rawValue.createUniqueVarName(nodeId: nodeId)
            
            let args: [String] = try patchNodeEntity.inputs.map { $0.portData }
                .createSwiftUICodeArgs(patchNodeEntityMap: patchNodeEntityDict)
            
            let fnNameSpace = isJSNode ? "Self.fn_\(varName)" : """
            NATIVE_STITCH_PATCH_FUNCTIONS["\(patchNodeEntity.patch.aiDisplayTitle)"]
            """
            
            let patchDeclaration = """
                let \(varName) = \(fnNameSpace)([
                        \(args.joined(separator: ",\n\t\t"))
                    ])
                """
            
            varIdNameMap.updateValue(varName, forKey: nodeId)
            return patchDeclaration
        }
        
        // Save scripts for JS nodes
        let jsNodeFns: [String: String] = patchNodeEntityDict.values.reduce(into: .init()) { result, node in
            guard let jsSettings = node.javaScriptNodeSettings else {
                return
            }
            
            let varName = node.patch.rawValue.createUniqueVarName(nodeId: node.id)
//            let fnName = "fn_\(varName)"
            
            result.updateValue(jsSettings.script, forKey: varName)
        }
        
        // Create new script that maps var names to some ID, which we use later to get actual UUID for node
        let varNameIdMap = varIdNameMap.reduce(into: [String : String]()) { result, data in
            result.updateValue(data.key.uuidString, forKey: data.value)
        }
        
        // Create @State assignments based on patch connections into layers
        let layerStateAssignments = viewStatePatchConnections.compactMap { (stateVarName, patchOutputCoordinate) -> String? in
            guard let patchId = UUID(patchOutputCoordinate.node_id),
                  let patchNodeVarName = varIdNameMap.get(patchId) else {
                fatalErrorIfDebug()
                return nil
            }
            
            return "\(stateVarName) = \(patchNodeVarName)[\(patchOutputCoordinate.port_index)]"
        }
        
        return .init(patchNodeDeclarations: patchNodeDeclarations + layerStateAssignments,
                     jsNodeFns: jsNodeFns,
                     varNameIdMap: varNameIdMap)
    }
}

extension String {
    func createUniqueVarName(nodeId: UUID) -> String {
        "\(self)_\(nodeId.uuidString)"
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}
