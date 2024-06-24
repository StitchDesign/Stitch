//
//  SidebarVisibilityUtils.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let SIDEBAR_VISIBILITY_STATUS_PRIMARY_HIDDEN_ICON = "eye.slash"
let SIDEBAR_VISIBILITY_STATUS_SECONDARY_HIDDEN_ICON = "circle.fill"
let SIDEBAR_VISIBILITY_STATUS_VISIBLE_ICON = "eye"
let SIDEBAR_VISIBILITY_STATUS_HIDDEN_ICON = "eye.slash"

let SIDEBAR_VISIBILITY_STATUS_PRIMARY_HIDDEN_COLOR: Color = EDIT_MODE_HAMBURGER_DRAG_ICON_COLOR
let SIDEBAR_VISIBILITY_STATUS_SECONDARY_HIDDEN_COLOR: Color = Color(uiColor: .darkGray)
let SIDEBAR_VISIBILITY_STATUS_VISIBLE_COLOR: Color = .white

extension GraphState {
    func getVisibilityStatus(for layerNodeId: NodeId) -> SidebarVisibilityStatus {
        
        guard let layerNode = self
            .getLayerNode(id: layerNodeId)?
            .layerNode else {
            log("getVisibilityStatus: could not find layer node \(layerNodeId)")
            return .visible
        }
        
        if !layerNode.hasSidebarVisibility {
            return .hidden
        }

        // Secondarily hidden if some upstream node is invisible
        if isUpstreamNodeInvisible(for: layerNode) {
            return .secondarilyHidden
        }

        return .visible
    }

    func isUpstreamNodeInvisible(for layerNode: LayerNodeViewModel) -> Bool {
        guard let groupId = layerNode.layerGroupId,
              let layerGroup = self.nodes.get(groupId)?.layerNode else {
            return false
        }

        // Recursion breaks if upstream node set to invisible
        if !layerGroup.hasSidebarVisibility {
            return true
        }

        // Keep checking upstream
        return isUpstreamNodeInvisible(for: layerGroup)
    }
}
