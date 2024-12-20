//
//  NodePageData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/27/23.
//

import SwiftUI
import StitchSchemaKit

typealias NodesPagingDict = [NodePageType: NodePageData]

@Observable
final class NodePageData {
    // The graph's movement (offset, momentum, etc.) for this traversal level
    var localPosition: CGPoint = .init()

    // TODO: you probably only need to save the zoomData.final, since that's roughly equivalent during a magnification gesture to localPosition during a graph scroll gesture
    let zoomData = GraphZoom()

    init(localPosition: CGPoint = .init(),
         zoomFinal: Double = 1) {
        self.localPosition = localPosition
        self.zoomData.final = zoomFinal
    }
}

/// Types of node paging, aka, the nodes that are visible. Either we're at the root
/// or visiting some group.
enum NodePageType: Hashable {
    case root
    case group(NodeId)
}

extension NodePageType {
    var getGroupNodePage: NodeId? {
        switch self {
        case .root:
            return nil
        case .group(let groupNodeId):
            return groupNodeId
        }
    }
}

extension NodeId? {
    var nodePageType: NodePageType {
        guard let groupNodeId = self else {
            return .root
        }

        return .group(groupNodeId)
    }
}
