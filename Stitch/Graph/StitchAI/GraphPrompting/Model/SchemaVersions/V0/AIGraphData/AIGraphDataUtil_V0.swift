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
    
    init(from graphEntity: GraphEntity) {
        let nodeDict = graphEntity.nodes.reduce(into: [UUID : NodeEntity]()) { result, node in
            result.updateValue(node, forKey: node.id)
        }
        
        let aiLayerData: [AIGraphData_V0.LayerData]
    }
}

extension Array where Element == AIGraphData_V0.SidebarLayerData {
//    init(from sidebarListData: [SidebarLayerData]) {
    func createAIData -> [AIGraphData_V0.LayerData] {
        self.map { sidebarData in
            
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
        
        let children = sidebarData.children?.createAIData()
        
        let customInputValues: [AIGraphData_V0.CustomLayerInputValue] = try LayerInputPort_V31.LayerInputPort
            .allCases.compactMap { port in
                let migratedPortData = try port.convert(to: LayerInputPort.self)
                let portData = layerData[keyPath: migratedPortData]
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
