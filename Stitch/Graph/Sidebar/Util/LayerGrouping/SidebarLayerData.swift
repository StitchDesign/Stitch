//
//  SidebarLayerData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/12/24.
//

import Foundation
import StitchSchemaKit
import StitchViewKit
import SwiftUI
import OrderedCollections

typealias SidebarLayerList = [SidebarLayerData]

typealias OrderedSidebarLayers = SidebarLayerList

extension SidebarLayerList {
    /// Returns ids just at a single hierarchy without recursively gathering other ids.
    var idsAtHierarchy: NodeIdSet {
        self.map { $0.id }
            .toSet
    }

    /// Gets flattened list of IDs recursively.
    func getIds() -> NodeIdList {
        self.flatMap {
            [$0.id] + ($0.children?.getIds() ?? [])
        }
    }
}

extension GraphState {
    func createSidebarLayerType(layerNode: LayerNodeViewModel) -> SidebarLayerData {
        if layerNode.layer == .group {
            // Find all nodes with this group
            let childrenLayerNodes = self.layerNodes.values
                .filter { $0.layerNode?.layerGroupId == layerNode.id }
                .compactMap { node -> SidebarLayerData? in
                    guard let layerNode = node.layerNode else {
                        #if DEBUG
                        fatalError()
                        #endif
                        return nil
                    }

                    // Recursively build sidebar items for childen
                    return self.createSidebarLayerType(layerNode: layerNode)
                }

            // Implicitly unsorted for now
            return .init(id: layerNode.id, children: childrenLayerNodes)
        }

        return .init(id: layerNode.id)
    }
}

extension SidebarLayerData: StitchNestedListElement {
    public static func createId() -> UUID {
        UUID()
    }
}
