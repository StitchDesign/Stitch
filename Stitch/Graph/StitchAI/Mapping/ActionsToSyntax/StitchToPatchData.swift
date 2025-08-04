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
            
            let varName = patchNodeEntity.patch.rawValue.createUniqueVarName(nodeId: nodeId)
            
            let args: [String] = try patchNodeEntity.inputs.map { inputData in
                switch inputData.portData {
                case .values(let values):
                    guard let firstValue = values.first else {
                        fatalError()
                    }
                    
                    let valueDesc = PrintablePortValueDescription(firstValue)
                    let string = try valueDesc.jsonWithoutQuotedKeys()
                    
                    // gets rid of brackets
                    let trimmedStr = string.dropFirst().dropLast()
                    return "[PortValueDescription(\(trimmedStr))]"
                    
                case .upstreamConnection(let upstream):
                    // Variable name should already exist given topological order, otherwise its a cycle case which we should ignore
                    guard let upstreamVarName = varIdNameMap.get(upstream.nodeId),
                          let portId = upstream.portId else {
                        throw SwiftUISyntaxError.upstreamVarNameNotFound(upstream)
                    }
                    
                    return "\(upstreamVarName)[\(portId)]"
                }
            }
            
            let patchDeclaration = """
                let \(varName) = NATIVE_STITCH_PATCH_FUNCTIONS["\(patchNodeEntity.patch.aiDisplayTitle)"]([
                        \(args.joined(separator: ",\n\t\t"))
                    ])
                """
            
            varIdNameMap.updateValue(varName, forKey: nodeId)
            return patchDeclaration
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
                     varNameIdMap: varNameIdMap)
    }
}

extension String {
    func createUniqueVarName(nodeId: UUID) -> String {
        "\(self)_\(nodeId.uuidString)"
            .replacingOccurrences(of: "-", with: "_")
    }
}
