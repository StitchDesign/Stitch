//
//  AIGraphDataUtil.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/15/25.
//

import SwiftUI
import StitchSchemaKit

enum AICodeGenError: Error {
    case nodeDataNotFound
}

extension AIGraphData_V0 {
    typealias GraphEntity = GraphEntity_V31.GraphEntity
    typealias NodeEntity = NodeEntity_V31.NodeEntity
    typealias LayerNodeEntity = LayerNodeEntity_V31.LayerNodeEntity
    typealias SidebarLayerData = SidebarLayerData_V31.SidebarLayerData
}

extension AIGraphData_V0.GraphData {
    
    init(from graphEntity: AIGraphData_V0.GraphEntity) throws {
        let nodesDict = graphEntity.nodes.reduce(into: [UUID : AIGraphData_V0.NodeEntity]()) { result, node in
            result.updateValue(node, forKey: node.id)
        }
        
        let aiLayerData: [AIGraphData_V0.LayerData] = try graphEntity.orderedSidebarLayers
            .createAIData(nodesDict: nodesDict)
    }
}

extension Array where Element == AIGraphData_V0.SidebarLayerData {
    func createAIData(nodesDict: [UUID : AIGraphData_V0.NodeEntity]) throws -> [AIGraphData_V0.LayerData] {
        try self.map { sidebarData in
            try .init(from: sidebarData,
                      nodesDict: nodesDict)
        }
    }
}

extension AIGraphData_V0.LayerData {
    init(from sidebarData: AIGraphData_V0.SidebarLayerData,
         nodesDict: [UUID : AIGraphData_V0.NodeEntity]) throws {
        guard let node = nodesDict.get(sidebarData.id),
              let layerData = node.layerNodeEntity else {
            throw AICodeGenError.nodeDataNotFound
        }
        
        // Recursively create children
        let children = try sidebarData.children?.createAIData(nodesDict: nodesDict)
        
        let customInputValues: [AIGraphData_V0.CustomLayerInputValue] = try LayerInputPort_V31.LayerInputPort
            .allCases.compactMap { port in
                let portData = layerData[keyPath: port.schemaPortKeyPath]
                
                switch portData.packedData.inputPort {
                case .values(let values):
                    let defaultData = port.getDefaultValue(for: layerData.layer)
                    
                    // Save data if different from default value
                    if let firstValue = values.first,
                       defaultData != firstValue {
                        return try .init(id: layerData.id,
                                         input: port,
                                         value: firstValue)
                    }
                    
                    return nil
                    
                case .upstreamConnection:
                    // Ignore upstream connection
                    return nil
                }
            }
        
        self = .init(node_id: sidebarData.id.description,
                     node_name: .init(value: layerData.layer.patchOrLayer),
                     children: children,
                     custom_layer_input_values: customInputValues)
    }
}

extension AIGraphData_V0.NodeEntity {
    var layerNodeEntity: AIGraphData_V0.LayerNodeEntity? {
        switch self.nodeTypeEntity {
        case .layer(let layerNodeEntity):
            return layerNodeEntity
            
        default:
            return nil
        }
    }
}
