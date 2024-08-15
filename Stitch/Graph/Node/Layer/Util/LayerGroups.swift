//
//  Groups.swift
//  prototype
//
//  Created by Christian J Clampitt on 7/28/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Find the parent, if any, for this layer node.
func findGroupLayerParentForLayerNode(_ nodeId: LayerNodeId,
                                      _ groups: SidebarGroupsDict) -> LayerNodeId? {

    groups.first { (_: LayerNodeId, value: LayerIdList) in
        value.contains(nodeId)
    }?.key
}

extension GraphState {
    // Assumes:
    // - all selected nodes have either same parent or no parent ('top level')
    @MainActor
    func getParentSizeForSelectedNodes(selectedNodes: NodeIdSet) -> CGSize {

        if let firstSelectedNode = selectedNodes.first,
           let layerNode = self.getNodeViewModel(firstSelectedNode)?.layerNode,
           let parentId = layerNode.layerGroupId {
            return self.parentSizeHelper(id: parentId)
        }
        // had no parent, so is just a top level item
        else {
            return previewWindowSize
        }
    }

    // Find the CGSize (not LayerSize)
    @MainActor
    private func parentSizeHelper(id: NodeId) -> CGSize {

        guard let node = self.getNodeViewModel(id),
              let nodeLayerSize = node.layerNode?.layerSize(activeIndex) else {
            return .zero
        }

        // if this layer node has a directly usable size,
        // just return that
        if let size = nodeLayerSize.asCGSize {
            return size
        }
        // else, if this layer-node has its own parent-node, try to find that
        // parent-node's size, and provide it to LayerSize
        else if let layerNode = self.getNodeViewModel(id)?.layerNode,
                let parentId = layerNode.layerGroupId {
            let sizeFromAbove = self.parentSizeHelper(id: parentId)
            return nodeLayerSize.asCGSize(sizeFromAbove)
        }
        // else this layer node is already top level
        else {
            let sizeFromPreviewWindow = nodeLayerSize.asCGSize(previewWindowSize)
            return nodeLayerSize.asCGSize(sizeFromPreviewWindow)
        }
    }
}

struct LayerGroupFit {
    // size for the Group Layer node
    let size: LayerSize

    // position for the Group Layer node
    let position: StitchPosition

    // How much to adjust the children's positions.
    // Only non-zero when a child was north and/or west
    let childAdjustment: CGSize

    init(_ size: LayerSize,
         _ position: StitchPosition,
         _ childAdjustment: CGSize) {
        self.size = size
        self.position = position
        self.childAdjustment = childAdjustment
    }
}

extension NodeViewModel {
    @MainActor
    func updateLayerNodePositionInput(offset: CGSize,
                                      activeIndex: ActiveIndex) {

        guard let layerViewModel = self.layerNode else {
            log("updateLayerNodePositionInput: called for layer that did not have position", .logToServer)
            return
        }
        
        let inputPort = layerViewModel.positionPort
        let updatedPositions: PortValues = inputPort.allLoopedValues.map { $0.getPoint ?? .zero }
            .map {
                updatePosition(position: $0, offset: offset.toCGPoint)
                    .toCGSize
            }
            .map(PortValue.position)

        inputPort.updatePortValues(updatedPositions)
    }
}
