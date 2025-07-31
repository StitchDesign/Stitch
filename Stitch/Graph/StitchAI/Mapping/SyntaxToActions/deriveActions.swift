//
//  deriveActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/25.
//

import Foundation
import SwiftUI

struct SwiftSyntaxLayerActionsResult: Encodable {
    var actions: [CurrentAIGraphData.LayerData]
    var caughtErrors: [SwiftUISyntaxError]
}

struct SwiftSyntaxPatchActionsResult: Encodable {
    var actions: CurrentAIGraphData.PatchData
    
    // Tracks any upstream patches that connect to some state
    // Key = state variable name
    // Value = upstream coordinate
    let viewStatePatchConnections: [String : AIGraphData_V0.NodeIndexedCoordinate]
    
    var caughtErrors: [SwiftUISyntaxError]
}

struct SwiftSyntaxActionsResult: Encodable {
    var graphData: CurrentAIGraphData.GraphData
    
    // Tracks any upstream patches that connect to some state
    // Key = state variable name
    // Value = upstream coordinate
    let viewStatePatchConnections: [String : AIGraphData_V0.NodeIndexedCoordinate]
    
    var caughtErrors: [SwiftUISyntaxError]
}

extension Array where Element == SyntaxView {
    func deriveStitchActions() throws -> SwiftSyntaxLayerActionsResult {
        let allResults = try self.map { try $0.deriveStitchActions() }
        
        return .init(actions: allResults.flatMap { $0.actions },
                     caughtErrors: allResults.flatMap { $0.caughtErrors })
    }
}

extension SwiftUIViewParserResult {
    func deriveStitchActions() throws -> SwiftSyntaxActionsResult {
        // Extract patch data
        let patchResults = try self.bindingDeclarations.deriveStitchActions()

        // Extract layer data
        let layerResults = try self.rootView?.deriveStitchActions()
        let allLayerErrors = layerResults.flatMap { $0.caughtErrors } ?? []
        
        return .init(graphData: .init(layer_data_list: layerResults?.actions ?? [],
                                      patch_data: patchResults.actions),
                     viewStatePatchConnections: patchResults.viewStatePatchConnections,
                     caughtErrors: allLayerErrors + patchResults.caughtErrors)
    }
}

//extension SwiftParserInitializerType {
//    func deriveNodeId(from varName: String) -> UUID? {
//        let nodeIdString = String(varName.split(separator: "_")[safe: 1] ?? "")
//        let decodedId = UUID(uuidString: nodeIdString)
//    }
//}

//extension Dictionary where Key == String, Value == SwiftParserSubscript {
//    // Recursively map some subscript access back to a node id
//    func findUpstreamNodeId(refName: String,
//                            varNameIdMap: [String : UUID]) -> NodeId {
//        guard let outputPortData = self.get(refName) else {
//            fatalError()
//        }
//        
//        switch outputPortData.subscriptType {
//        case .patchNode(let patchNode)
//        }
//    }
//}

extension Dictionary where Key == String, Value == SwiftParserInitializerType {
    func deriveStitchActions() throws -> SwiftSyntaxPatchActionsResult {
        // MARK: data we use as tracking
        // Maps some variable name to a node ID string
        var varNameIdMap = [String : String]()
        
        // Maps any declarations made of top-level outputs
        var varNameOutputPortMap = [String : SwiftParserSubscript]()
        
        // Tracks @State variable declarations
        var viewStateVarNames = Set<String>()
        
        // MARK: data to be returned
        var caughtErrors: [SwiftUISyntaxError] = []
        var nativePatchNodes = [CurrentAIGraphData.NativePatchNode]()
        var nativePatchValueTypeSettings = [CurrentAIGraphData.NativePatchNodeValueTypeSetting]()
        var patchConnections = [CurrentAIGraphData.PatchConnection]()
        var customPatchInputValues = [CurrentAIGraphData.CustomPatchInputValue]()
        
        // Because patch data is decoded before layer data, we don't yet know the destination ports for layer edges, therefore, we just track the source patch to some state variable
        var viewStatePatchConnections = [String : AIGraphData_V0.NodeIndexedCoordinate]()
        
        // First pass:
        // 1. Create patch nodes
        // 2. Make mappings of var names to specific data
        for (varName, initializerType) in self {
            switch initializerType {
            case .patchNode(let patchNodeData):
                let newPatchNode = patchNodeData
                    .createStitchData(varName: varName,
                                      varNameIdMap: &varNameIdMap)
                nativePatchNodes.append(newPatchNode)
                
            case .subscriptRef(let subscriptData):
                // Track top-level bindings of some output port data
                varNameOutputPortMap.updateValue(subscriptData, forKey: varName)
                
                switch subscriptData.subscriptType {
                case .patchNode(let patchNodeData):
                    // Track more patch nodes
                    let newPatchNode = patchNodeData
                        .createStitchData(varName: varName,
                                          varNameIdMap: &varNameIdMap)
                    nativePatchNodes.append(newPatchNode)
                    
                case .ref:
                    continue
                }
                
            case .stateMutation:
                // Create state with disconnected upstream patch port, feed this into layer data and update all the helpers
                viewStateVarNames.insert(varName)
            }
        }
        
        // Second pass: derive custom values and edges
        for (varName, initializerType) in self {
            switch initializerType {
            case .patchNode(let patchNodeData):
                for (portIndex, arg) in patchNodeData.args.enumerated() {
                    switch arg {
                    case .binding(let declRefSyntax):
                        // Get edge data
                        let refName = declRefSyntax.baseName.text
                                                
                        guard let upstreamRefData = varNameOutputPortMap.get(refName) else {
                            fatalError()
                        }
                        
                        let usptreamCoordinate = SwiftParserPatchData
                            .derivePatchUpstreamCoordinate(upstreamRefData: upstreamRefData,
                                                           varNameIdMap: varNameIdMap)
                        
                        patchConnections.append(
                            .init(src_port: usptreamCoordinate,
                                  dest_port: .init(node_id: patchNodeData.id,                          port_index: portIndex))
                        )
                        
                    case .value(let argType):
                        let portDataList = try argType.derivePortValues()
                        
                        for portData in portDataList {
                            switch portData {
                            case .value(let portValue):
                                customPatchInputValues.append(
                                    .init(patch_input_coordinate: .init(
                                        node_id: patchNodeData.id,
                                        port_index: portIndex),
                                          value: portValue.anyCodable,
                                          value_type: .init(value: portValue.nodeType))
                                )
                                
                            case .stateRef(let string):
                                fatalErrorIfDebug("State variables should never be passed into patch nodes")
                                throw SwiftUISyntaxError.unsupportedStateInPatchInputParsing(patchNodeData)
                            }
                        }
                    }
                }
                
            case .stateMutation(let subscriptData):
                // Track upstream patch coordinate to some TBD layer input
                let usptreamCoordinate = SwiftParserPatchData
                    .derivePatchUpstreamCoordinate(upstreamRefData: subscriptData,
                                                   varNameIdMap: varNameIdMap)
                
                viewStatePatchConnections.updateValue(usptreamCoordinate,
                                                      forKey: varName)
                
            case .subscriptRef:
                // Ignore here
                continue
            }
        }
        
        return .init(actions: AIGraphData_V0
            .PatchData(javascript_patches: [],
                       native_patches: nativePatchNodes,
                       native_patch_value_type_settings: nativePatchValueTypeSettings,
                       patch_connections: patchConnections,
                       custom_patch_input_values: customPatchInputValues,
                       // Layer connections cannot yet be determined here
                       layer_connections: []),
                     viewStatePatchConnections: viewStatePatchConnections,
                     caughtErrors: caughtErrors)
    }
}

extension SyntaxView {
    func deriveStitchActions() throws -> SwiftSyntaxLayerActionsResult {
        // TODO: map references to specific layer IDs
        
        // Tracks all silent errors
        var silentErrors = [SwiftUISyntaxError]()
        
        // Recurse into children first (DFS), we might use this data for nested scenarios like ScrollView
        var childResults = try self.children.deriveStitchActions()
        
        // Flip the children if we have a ZStack,
        // since "top" layer in Stitch sidebar corresponds to "bottom" of declared-child in SwiftUI ZStack.
        if self.name == .zStack {
            childResults.actions = childResults.actions.reversed()
            
            // TODO: do we really need to reverse the errors?
            childResults.caughtErrors = childResults.caughtErrors.reversed()
        }
        
        silentErrors += childResults.caughtErrors

        // Map this node
        do {
            let layerDataResult = try self.name.deriveLayerData(
                id: self.id,
                args: self.constructorArguments,
                modifiers: self.modifiers,
                childrenLayers: childResults.actions)
            
            silentErrors += layerDataResult.silentErrors
            var layerData = layerDataResult.layerData
            
            guard let layer = layerData.node_name.value.layer else {
                fatalErrorIfDebug("deriveStitchActions error: no layer found for \(layerData.node_name.value)")
                throw SwiftUISyntaxError.layerDecodingFailed
            }
            
            if !layer.isGroupForAI {
                // Make sure non-grouped layer has no children
                assertInDebug(childResults.actions.isEmpty)
                layerData.children = nil
            }
    
            return .init(actions: [layerData],
                         caughtErrors: silentErrors)
        } catch let error as SwiftUISyntaxError {
            if error.shouldFailSilently {
                log("deriveStitchActions: silent failure for unsupported layer concept: \(error)")
                // Silent error for unsupported layers
                silentErrors.append(error)
                return .init(actions: childResults.actions,
                             caughtErrors: silentErrors)
            } else {
                throw error
            }
        } catch {
            throw error
        }
    }
}

extension SyntaxViewName {
    /// Handles ScrollView-specific logic including axis detection and scroll behavior
    static func createScrollGroupLayer(args: [SyntaxViewArgumentData],
                                       childrenLayers: [CurrentAIGraphData.LayerData]) throws -> CurrentAIGraphData.LayerData {
        // Check the scroll axis from constructor arguments
        // let scrollAxis = Self.detectScrollAxis(args: args)
      
        // var groupLayer: CurrentAIGraphData.LayerData
        let isFirstLayerGroup = childrenLayers.first?.node_name.value.layer?.isGroupForAI ?? false
        let hasRootGroupLayer = childrenLayers.count == 1 && isFirstLayerGroup
        
        // Create a new nested VStack if no root group
        if hasRootGroupLayer,
           let _groupData: CurrentAIGraphData.LayerData = childrenLayers.first {
            return _groupData
        } else if !hasRootGroupLayer {
            // Add new node as middle-man
            let newId = UUID()
            let newGroupNode = CurrentAIGraphData
                .LayerData(node_id: newId.description,
                           node_name: .init(value: .layer(.group)),
                           children: childrenLayers,
                           // the new group node should be a VStack, i.e. a layer group with orientation = .vertical
                           custom_layer_input_values: [
                            LayerPortDerivation(input: .orientation,
                                                value: .orientation(.vertical))
                           ])
                        
            return newGroupNode
        } else {
            fatalErrorIfDebug("Unexpected scenario for groups in scroll.")
            throw SwiftUISyntaxError.groupLayerDecodingFailed
        }
    }
}


// https://developer.apple.com/documentation/swiftui/color#Getting-standard-colors
extension Color {
    /// Converts a textual system-color name (“yellow”, “.yellow”, “Color.yellow”)
    /// into a `SwiftUI.Color`. Returns `nil` for unknown names.
    static func fromSystemName(_ raw: String) -> Color? {
        // ── 1. Normalise ────────────────────────────────────────────────────────
        var key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.hasPrefix("Color.") { key.removeFirst("Color.".count) }
        if key.hasPrefix(".")      { key.removeFirst() }

        // ── 2. Lookup ───────────────────────────────────────────────────────────
        switch key.lowercased() {
        case "black":   return .black
        case "blue":    return .blue
        case "brown":   return .brown
        case "clear":   return .clear
        case "cyan":    return .cyan
        case "gray",    // US spelling
             "grey":    // convenience UK spelling
                        return .gray
        case "green":   return .green
        case "indigo":  return .indigo
        case "mint":    return .mint
        case "orange":  return .orange
        case "pink":    return .pink
        case "purple":  return .purple
        case "red":     return .red
        case "teal":    return .teal
        case "white":   return .white
        case "yellow":  return .yellow
        default:        return nil        // not a standard color
        }
    }
}
