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
        
    // TODO: portType.portIndex vs .keyPath is not enough to create a canvas item id, since that can be for
    
    // InputCoordinate -> CanvasItemId = keypath is always for layer input, port id is always for patch input
    var inputCoordinateAsCanvasItemId: CanvasItemId {
        switch self.portType {
            
        // PortIndex = this is an address for an input on a patch or group node,
        // i.e. a node canvas item
        case .portIndex:
            return .node(self.nodeId)
            
        // KeyPath = this is an address for layer-input on the graph,
        // i.e. a layer-input-on-graph canvas item
        case .keyPath(let x):
            return .layerInput(LayerInputCoordinate(node: self.nodeId,
                                                    keyPath: x))
        }
    }
    
    // OutputCoordinate -> CanvasItemId = keypath not allowed; and port id could be either patch node id or
    // output on node = Ca
    @MainActor
    func outputCoordinateAsCanvasItemId(_ graph: GraphDelegate) -> CanvasItemId {
     
        // PortType.keyPath can NEVER be used with an output. We MUST use a port-id for outputs.
        guard let portId = self.portId else {
            fatalErrorIfDebug()
            return .node(self.nodeId)
        }
        
        let isLayer = graph.getNodeViewModel(self.nodeId)?.kind.isLayer ?? false
        
        if isLayer {
            return .layerOutput(LayerOutputCoordinate(node: self.nodeId,
                                                      portId: portId))
        } else {
            return .node(self.nodeId)
        }
    }
}

extension StitchDocumentViewModel {
    func createEdges() -> Edges {
        self.connections.reduce(into: []) { partialResult, connection in
            partialResult += connection.value.map { PortEdgeData(from: connection.key,
                                                                 to: $0) }
        }
    }
}
