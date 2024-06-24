//
//  LayerNodeId.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/7/22.
//

import Foundation
import StitchSchemaKit
import SwiftUI

extension LayerNodeId {
    static var randomLayerNodeId: LayerNodeId {
        NodeId.randomNodeId.asLayerNodeId
    }

    var asItemId: SidebarListItemId {
        SidebarListItemId(id)
    }

    var asNodeId: NodeId {
        self.id
    }

}

typealias LayerIdList = [LayerNodeId]
typealias LayerIdSet = Set<LayerNodeId>
typealias NonEmptyLayerIdSet = NES<LayerNodeId>
