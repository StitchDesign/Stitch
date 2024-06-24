//
//  LayerNodesForSidebarDict.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import SwiftUI
import StitchSchemaKit
import OrderedCollections

typealias LayerNodesForSidebarDict = OrderedDictionary<LayerNodeId, LayerNodeForSidebar>

// All the data the sidebar needs about a layer
struct LayerNodeForSidebar: Equatable, Codable, Hashable {
    let id: LayerNodeId
    let layer: Layer
    let displayTitle: String
}
