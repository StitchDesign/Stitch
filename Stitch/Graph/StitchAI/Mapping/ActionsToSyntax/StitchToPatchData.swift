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
                                   viewStatePatchConnections: [String : [NodeConnectionType]]) throws -> StitchPatchCodeConversionResult {
        // Maps node IDs to a new var name
        var varIdNameMap: [UUID: String] = [:]
        
        let patchNodeEntityDict = self.nodes.reduce(into: [UUID: PatchNodeEntity]()) { result, nodeEntity in
            if let patchNodeEntity = nodeEntity.nodeTypeEntity.patchNodeEntity {
                result.updateValue(patchNodeEntity, forKey: nodeEntity.id)
            }
        }
        
        let patchNodeDeclarations = try nodeIdsInTopologicalOrder.compactMap { nodeId -> String? in
            guard let patchNodeEntity = patchNodeEntityDict.get(nodeId),
                  !patchNodeEntity.patch.isInteractionPatchNode else {
                // Layer node and interaction node, return nil
                return nil
            }
            
            let isJSNode = patchNodeEntity.patch == .javascript
            let varName = patchNodeEntity.patch.createUniqueVarName(nodeId: nodeId)
            
            let args: [String] = try patchNodeEntity.inputs.map { $0.portData }
                .createSwiftUICodeArgs(patchNodeEntityMap: patchNodeEntityDict)
            
            let fnNameSpace = isJSNode ? "Self.fn_\(varName)" : """
            NATIVE_STITCH_PATCH_FUNCTIONS["\(patchNodeEntity.patch.aiDisplayTitle)"]
            """
            
            let patchDeclaration = """
                let \(varName) = \(fnNameSpace)([
                \(args.joined(separator: ",\n").indentLines(n: 2))
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
            
            let varName = node.patch.createUniqueVarName(nodeId: node.id)
//            let fnName = "fn_\(varName)"
            
            result.updateValue(jsSettings.script, forKey: varName)
        }
        
        // Create new script that maps var names to some ID, which we use later to get actual UUID for node
        let varNameIdMap = varIdNameMap.reduce(into: [String : String]()) { result, data in
            result.updateValue(data.key.uuidString, forKey: data.value)
        }
        
        // Create @State assignments based on patch connections into layers
        let layerStateAssignments = viewStatePatchConnections.compactMap { (stateVarName, patchOutputCoordinates) -> String? in
            // Only multiple count here when parsing AI code
            assertInDebug(patchOutputCoordinates.count == 1)
            guard let patchOutputCoordinate = patchOutputCoordinates.first?.upstreamConnection else { return nil }
            
            let patchId = patchOutputCoordinate.nodeId

            guard let patchNodeVarName = varIdNameMap.get(patchId) else {
                // Valid nil case for interaction nodes, which aren't saved to map
                return nil
            }
            
            return "\(stateVarName) = \(patchNodeVarName)[\(patchOutputCoordinate.portId ?? 0)]"
        }
        
        return .init(patchNodeDeclarations: patchNodeDeclarations + layerStateAssignments,
                     jsNodeFns: jsNodeFns,
                     varNameIdMap: varNameIdMap)
    }
}

extension Patch {
    func createUniqueVarName(nodeId: UUID) -> String {
        let patchString = self.defaultDisplayTitle().toCamelCase()
        
        return patchString.createUniqueVarName(nodeId: nodeId)
    }
}

extension String {
    func createUniqueVarName(nodeId: UUID) -> String {
        "\(self)_\(nodeId.uuidString)"
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }
}

extension Patch {
    func getGestureName(for outputPortIndex: Int) -> String {
        switch self {
        case .dragInteraction:
            return outputPortIndex == 0 ? "position" : "translation"
            
        case .pressInteraction:
            return "pulse"
            
        default:
            fatalErrorIfDebug()
            return ""
        }
    }
    
    func createInteractionStateVarName(layerId: UUID,
                                       outputPortIndex: Int) -> String {
        let gestureName = self.getGestureName(for: outputPortIndex)
        let uniqueVar = "layer".createUniqueVarName(nodeId: layerId)
        return "\(uniqueVar)_\(gestureName)"
    }
}
