//
//  NodeRowViewModelId.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation


struct NodeRowViewModelId: Hashable {
    var graphItemType: GraphItemType
    var nodeId: NodeId
    
    // TODO: this is always 0 for layer inspector which creates issues for tabbing
    var portId: Int
}

extension NodeRowViewModelId {
    /// Determines if some row view model reports to a node, rather than to the layer inspector
    var isNode: Bool {
        switch self.graphItemType {
        case .node:
            return true
        default:
            return false
        }
    }
        
    static let empty: Self = .init(graphItemType: .node(.node(.init())),
                                   nodeId: .init(),
                                   portId: -1)
    
    var layerInputPort: LayerInputPort? {
        self.graphItemType.layerInputPort
    }
}
