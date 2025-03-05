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
    // TODO: for root page data, should always be same as the persisted localPosition of GraphEntity; currently we only persist a single localPosition on the document entity
    var localPosition: CGPoint {
        didSet {
            // log("NodePageData: didSet: localPosition: oldValue: \(oldValue)")
            // log("NodePageData: didSet: localPosition: localPosition: \(localPosition)")
            if localPosition.x.magnitude > WHOLE_GRAPH_LENGTH {
                fatalErrorIfDebug()
            }
            if localPosition.y.magnitude > WHOLE_GRAPH_LENGTH {
                fatalErrorIfDebug()
            }
        }
    }

    var zoomData: CGFloat

    init(localPosition: CGPoint, zoomFinal: Double = 1) {
        // log("NodePageData: init: localPosition: \(localPosition)")
        // log("NodePageData: init: zoomFinal: \(zoomFinal)")
        var localPosition = localPosition
        if (localPosition.x.magnitude > WHOLE_GRAPH_LENGTH) || (localPosition.y.magnitude > WHOLE_GRAPH_LENGTH) {
            fatalErrorIfDebug()
            log("NodePageData: localPosition was too large: \(localPosition)", .logToServer)
            localPosition = ABSOLUTE_GRAPH_CENTER
        }
        self.localPosition = localPosition
        self.zoomData = zoomFinal
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
