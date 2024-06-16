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

extension GraphState {
    func createEdges() -> Edges {
        self.connections.reduce(into: []) { partialResult, connection in
            partialResult += connection.value.map { PortEdgeData(from: connection.key,
                                                                 to: $0) }
        }
    }
}
