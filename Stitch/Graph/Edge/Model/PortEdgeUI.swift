//
//  PortEdgeUI.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation

typealias VisibleEdges = [PortEdgeUI]

// Better: `GraphEdge`
struct PortEdgeUI: Equatable, Hashable {
    let from: PortViewData // ie nodeId, portId
    let to: PortViewData
}

extension PortEdgeUI: Identifiable {
    // Inputs can only have one edge so we use that as our identifiable
    var id: PortViewData {
        self.to
    }
    
    // NOT correct for cases of multiple outputs?
    var fromIndex: Int {
        self.from.portId + 1
    }
}
