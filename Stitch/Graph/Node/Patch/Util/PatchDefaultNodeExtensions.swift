//
//  PatchDefaultNodeExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension Patch {
    @MainActor
    var defaultNodeType: NodeType? {
        self.defaultNode(id: .init(),
                         position: .zero,
                         zIndex: .zero,
                         graphDelegate: .createEmpty()).userVisibleType
    }

    // called when we first place the patch on the graph
    // so we decide both the default port values AND the default user-visible-type
    @MainActor
    func defaultNode(id: NodeId, // = NodeId(),
                     position: CGPoint,
                     zIndex: Double,
                     // TODO: separate 'first creation of node' from 'recreation of node via schema'
                     //                     firstCreation: Bool = true,
                     graphTime: TimeInterval = .zero,
                     graphDelegate: GraphState) -> NodeViewModel {

        let GraphNodeType = PatchOrLayer.patch(self).graphNode
        return GraphNodeType.createViewModel(id: id,
                                           position: position,
                                           zIndex: zIndex,
                                           graphDelegate: graphDelegate)
    }
}
