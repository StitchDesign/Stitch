//
//  LayerGroupFit.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/10/24.
//

//
//  LayerGroupFit.swift
//  Stitch
//
//  Created by Christian J Clampitt on 7/19/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension GraphState {
//    // create the group fitting first,
//    // then apply the position offset to all the children
//    @MainActor
//    func getLayerGroupFit(_ selectedNodes: NodeIdSet,
//                          parentSize: CGSize,
//                          activeIndex: ActiveIndex) -> LayerGroupFit {
//        
//        var north: CGFloat = .zero
//        var south: CGFloat = .zero
//        var west: CGFloat = .zero
//        var east: CGFloat = .zero
//        
//        var northAdjustment: CGFloat?
//        var westAdjustment: CGFloat?
//        
//        // TODO: should be ADJUSTED active-index
//        
//        for selectedId in selectedNodes {
//            
//            // Must compare against "absolute size",
//            // ie the layer's size after parentSize and layer's own scale
//            // have been taken into account.
//            guard let layerNode = self.getNodeViewModel(selectedId)?.layerNode,
//                  let layerSize = layerNode.scaledLayerSize(for: selectedId,
//                                                            parentSize: parentSize,
//                                                            activeIndex: activeIndex),
//                  let layerPosition = layerNode.layerPosition(activeIndex) else {
//                log("getLayerGroupFit: could not get layerSize or layerPosition for node \(selectedId)")
//                continue
//            }
//
//            let layerNorth = layerPosition.y - layerSize.id.height/2
//            if layerNorth.magnitude > north.magnitude {
//                north = layerNorth
//                
//                // Use the position of the
//                // northernmost layer for our north-adjustment;
//                // but only if position is negative.
//                if layerPosition.y < 0 {
//                    northAdjustment = layerPosition.y.magnitude
//                }
//            }
//            
//            let layerSouth = layerPosition.y + layerSize.id.height/2
//            if layerSouth.magnitude > south.magnitude {
//                south = layerSouth
//            }
//            
//            let layerWest = layerPosition.x - layerSize.id.width/2
//            if layerWest.magnitude > west.magnitude {
//                west = layerWest
//                
//                // Use the position of the
//                // westernmost layer for our west-adjustment;
//                // but only if position is negative.
//                if layerPosition.x < 0 {
//                    westAdjustment = layerPosition.x.magnitude
//                }
//            }
//            
//            let layerEast = layerPosition.x + layerSize.id.width/2
//            if layerEast.magnitude > east.magnitude {
//                east = layerEast
//            }
//        }
//        
//        let height = abs(north) + abs(south)
//        let width = abs(west) + abs(east)
//        
//        let groupSize = LayerSize(width: width, height: height)
//        
//        // Group position and adjustment are non-zero only when
//        // some child is north and/or west (ie -y and/or -x positions).
//        let groupPosition = CGPoint(
//            x: westAdjustment.map(\.flipSign) ?? .zero,
//            y: northAdjustment.map(\.flipSign) ?? .zero)
//        
//        // Always either .zero or positive
//        let adjustment = CGSize(width: westAdjustment ?? .zero,
//                                height: northAdjustment ?? .zero)
//        
//        return .init(groupSize, groupPosition, adjustment)
//    }
//    
//    // The adjustment is only for 'NW' displacement;
//    // ie we ALWAYS add the displacement to the group's children's positions,
//    // (whereas we always SUBTRACT the displacement from the group's positions).
//    @MainActor
//    func adjustGroupChildrenToLayerFit(_ layerFit: LayerGroupFit,
//                                       _ selectedNodes: NodeIdSet) {
//        selectedNodes.forEach {
//            self.updateLayerNodePositionInput(
//                nodeId: $0,
//                offset: layerFit.childAdjustment)
//        }
//    }
    
//    @MainActor
//    func updateLayerNodePositionInput(nodeId: NodeId,
//                                      offset: CGSize,
//                                      activeIndex: ActiveIndex) {
//        guard let node = self.getNodeViewModel(id) else {
//            log("updateLayerNodePositionInput: called for layer that did not have position", .logToServer)
//            return
//        }
//        
//        node.updateLayerNodePositionInput(offset: offset,
//                                          activeIndex: activeIndex)
//    }
}
