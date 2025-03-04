//
//  LayerInteractionActions.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/12/23.
//

import Foundation
import StitchSchemaKit

extension Layer {
    /// Reality layer views don't allow looping.
    var disablesLooping: Bool {
        switch self {
        case .realityView:
            return true
        default:
            return false
        }
    }
}

extension InputNodeRowObserver {
    @MainActor
    func hasUpstreamInteractionNode(_ nodes: NodesViewModelDict, _ graph: GraphState) -> Bool {
        if let upstreamNodeId = self.getUpstreamOutputObserver(graph)?.id.nodeId,
           let upstreamNode = nodes.get(upstreamNodeId),
           upstreamNode.patch?.isInteractionPatchNode ?? false {
            return false
        }
        return true
    }
}
