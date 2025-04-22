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
    var isCanvas: Bool {
        switch self.graphItemType {
        case .canvas:
            return true
        default:
            return false
        }
    }
        
    static let empty: Self = .init(graphItemType: .canvas(.node(.init())),
                                   nodeId: .init(),
                                   portId: -1)
    
    var layerInputPort: LayerInputPort? {
        self.graphItemType.layerInputPort
    }
}
