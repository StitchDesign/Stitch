//
//  NodeInfo.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 11/16/23.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// legacy data structure? 
struct NodeInfo: Encodable {
    let name: String
    let inputs: [NodeInputDefinition]
    let outputs: [NodeOutputDefinition]
    //    let supportedTypes: Set<UserVisibleType>
    let nodeDescription: String
    let supportsNewInputs: Bool
}

extension NodeInfo {
    @MainActor
    static func printAllNodeInfo() throws -> String {
        
        let graph = GraphState()
        
        let patchNodeInfo = Patch.allCases.map { patch in
            assertInDebug(patch.nodeDescription != nil)
            
            let node = patch.defaultNode(id: .init(),
                                         position: .zero,
                                         zIndex: .zero,
                                         graphDelegate: graph)
            //            var supportedTypes = Set<UserVisibleType>()
            //            switch patch {
            //            // These nodes have phased out `availableNodeTypes` for auto detetcing in coercion
            //            case .greaterOrEqual, .lessThanOrEqual, .equals, .greaterThan, .lessThan:
            //                supportedTypes = .init([.bool, .number, .string, .layerDimension])
            //            default:
            //                supportedTypes = patch.availableNodeTypes
            //            }

            return NodeInfo(name: node.displayTitle,
                            inputs: PatchOrLayer.patch(patch).rowDefinitionsOldOrNewStyle(for: node.userVisibleType).inputs,
                            outputs: PatchOrLayer.patch(patch).rowDefinitionsOldOrNewStyle(for: node.userVisibleType).outputs,
                            //                            supportedTypes: supportedTypes,
                            nodeDescription: patch.nodeDescription ?? "",
                            supportsNewInputs: patch.canChangeInputCounts)
        }

        let layerNodeInfo = Layer.allCases.map { layer in
            assertInDebug(layer.nodeDescription != nil)
            
            let node = layer.defaultNode(id: .init(),
                                         position: .zero,
                                         zIndex: .zero,
                                         graphDelegate: graph)

            return NodeInfo(name: node.displayTitle,
                            inputs: PatchOrLayer.layer(layer).rowDefinitionsOldOrNewStyle(for: node.userVisibleType).inputs,
                            outputs: PatchOrLayer.layer(layer).rowDefinitionsOldOrNewStyle(for: node.userVisibleType).outputs,
                            //                            supportedTypes: .init(),
                            nodeDescription: layer.nodeDescription ?? "",
                            supportsNewInputs: false)
        }

        let jsonData = try! JSONEncoder().encode(patchNodeInfo + layerNodeInfo)
        return try jsonData.createPrintableJsonString()
    }
}

// TODO: If only used for defining a node's default ("just-created") inputs, use `value: PortValue` instead of `defaultValues: PortValues`
// fka `NodeRowInputInfo`
struct NodeInputDefinition: Encodable {
    var defaultValues: PortValues
    let label: String
    var isTypeStatic = false
    
    // Specifically for layers
    var layerInputType: LayerInputPort?
    
    
    /// Favors directly transferring values from an upstream connection in favor of type coercion.
    /// Used for Delay and Delay 1 nodes.
    var canDirectlyCopyUpstreamValues: Bool = false
}

extension NodeInputDefinition {
    // Infers default value if not specified
    init(label: String,
         staticType: UserVisibleType,
         canDirectlyCopyUpstreamValues: Bool = false) {
        self.defaultValues = [staticType.defaultPortValue]
        self.label = label
        self.isTypeStatic = true
        self.canDirectlyCopyUpstreamValues = false
    }

    init(label: String = "",
         defaultType: UserVisibleType,
         isTypeStatic: Bool = false,
         canDirectlyCopyUpstreamValues: Bool = false) {
        self.defaultValues = [defaultType.defaultPortValue]
        self.label = label
        self.isTypeStatic = isTypeStatic
        self.canDirectlyCopyUpstreamValues = canDirectlyCopyUpstreamValues
    }
}

// fka `NodeRowOutputInfo`
struct NodeOutputDefinition: Encodable {
    let label: String
    let value: PortValue
}

extension NodeOutputDefinition {
    init(label: String = "",
         type: UserVisibleType) {
        self.label = label
        self.value = type.defaultPortValue
    }
}
