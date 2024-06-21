//
//  Edge.swift
//  prototype
//
//  Created by cjc on 1/14/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

typealias Edges = [PortEdgeData]
typealias EdgeSet = Set<PortEdgeData>

/// Data specific--not tied to the view. Used for cached `Connections` data.
struct PortEdgeData: Hashable {
    let from: NodeIOCoordinate
    let to: NodeIOCoordinate
}

extension NodeIOCoordinate {
    var asCanvasItemId: CanvasItemId {
        switch self.portType {
            
        // PortIndex = this is an address for an input on a patch or group node,
        // i.e. a node canvas item
        case .portIndex(let x):
            return .node(self.nodeId)
            
        // KeyPath = this is an address for layer-input on the graph,
        // i.e. a layer-input-on-graph canvas item
        case .keyPath(let x):
            return .layerInputOnGraph(LayerInputOnGraphId(node: self.nodeId,
                                                          keyPath: x))
        }
    }
}

extension GraphState {
    func createEdges() -> Edges {
        self.connections.reduce(into: []) { partialResult, connection in
            partialResult += connection.value.map { PortEdgeData(from: connection.key,
                                                                 to: $0) }
        }
    }
}
