//
//  LayerInspectorActions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
    // i.e. "layers focused in the inspector" are just the primarily-selected layers in the sidebar
    @MainActor
    var inspectorFocusedLayers: NodeIdSet {
        self.layersSidebarViewModel.selectionState.primary
    }
    
    @MainActor
    var inspectorFocusedLayerNodes: LayerNodes {
        self.layersSidebarViewModel.selectionState.primary
            .reduce(into: LayerNodes()) { acc, id in
                if let layerNode: LayerNodeViewModel = self.getLayerNode(id) {
                    acc.append(layerNode)
                }
            }
    }
    
    // TODO: cache these for perf
    @MainActor
    var nonEditModeSelectedLayerInLayerSidebar: NodeId? {
        self.sidebarSelectionState.all.first
    }
    
    // TODO: cache these for perf
    @MainActor
    var firstLayerInLayerSidebar: NodeId? {
        self.orderedSidebarLayers.first?.id
    }
    
    // TODO: support multiple layers being focused in propety sidebar
    // TODO: cache these for perf?
    /// The single layer currently focused in the inspector
    @MainActor
    var layerFocusedInPropertyInspector: NodeId? {
        self.nonEditModeSelectedLayerInLayerSidebar ?? self.firstLayerInLayerSidebar
    }
}

