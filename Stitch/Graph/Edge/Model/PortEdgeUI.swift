//
//  PortEdgeUI.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation

typealias VisibleEdges = [PortEdgeUI]

// TODO: make cleaner what PortEdgeUI is vs PortEdgeData; `PortEdgeData` is probably an older data form, from when InputCoordinate and OutputCoordinate were separate types
// Better: `GraphEdge`
struct PortEdgeUI: Equatable, Hashable {
    let from: OutputPortIdAddress // ie nodeId, portId
    let to: InputPortIdAddress
}

extension PortEdgeUI: Identifiable {
    // Inputs can only have one edge so we use that as our identifiable
    var id: InputPortIdAddress {
        self.to
    }
    
    // NOT correct for cases of multiple outputs?
    var fromIndex: Int {
        self.from.portId + 1
    }
}
