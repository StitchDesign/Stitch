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

extension Array where Element: StitchNestedListElementObservable {
    /// Returns ids just at a single hierarchy without recursively gathering other ids.
    var idsAtHierarchy: Set<Element.ID> {
        self.map { $0.id }
            .toSet
    }

    /// Gets flattened list of IDs recursively.
    @MainActor func getIds() -> [Element.ID] {
        self.flatMap {
            [$0.id] + ($0.children?.getIds() ?? [])
        }
    }
}

extension GraphState {
    @MainActor
    func createSidebarLayerType(layerNode: LayerNodeViewModel) -> SidebarLayerData {
        if layerNode.layer == .group {
            // Find all nodes with this group
            let childrenLayerNodes = self.layerNodes()
                .filter { $0.layerGroupId == layerNode.id }
                .compactMap { layerNode -> SidebarLayerData? in
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
