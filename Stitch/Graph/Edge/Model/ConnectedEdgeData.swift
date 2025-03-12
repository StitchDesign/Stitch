//
//  ConnectedEdgeData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 3/11/25.
//

import SwiftUI
import StitchSchemaKit

struct ConnectedEdgeData: Equatable {
    static func == (lhs: ConnectedEdgeData, rhs: ConnectedEdgeData) -> Bool {
        lhs.upstreamRowObserver.id == rhs.upstreamRowObserver.id &&
        lhs.downstreamRowObserver.id == rhs.downstreamRowObserver.id &&
        lhs.zIndex == rhs.zIndex
    }
    
    let upstreamRowObserver: OutputNodeRowViewModel
    let downstreamRowObserver: InputNodeRowViewModel
    let inputData: EdgeAnchorDownstreamData
    let outputData: EdgeAnchorUpstreamData
    let zIndex: Double
    
    @MainActor
    init?(downstreamRowObserver: InputNodeRowViewModel) {
        guard let downstreamNode = downstreamRowObserver.nodeDelegate,
              let upstreamRowObserver = downstreamRowObserver.rowDelegate?.upstreamOutputObserver?.nodeRowViewModel,
              let inputData = EdgeAnchorDownstreamData(
                from: downstreamRowObserver,
                upstreamNodeId: upstreamRowObserver.canvasItemDelegate?.id),
              let outputData = EdgeAnchorUpstreamData(
                from: upstreamRowObserver,
                connectedDownstreamNode: downstreamNode) else {
            return nil
        }
        
        self.upstreamRowObserver = upstreamRowObserver
        self.downstreamRowObserver = downstreamRowObserver
        self.inputData = inputData
        self.outputData = outputData
        
        let upstreamRowObserverZIndex = upstreamRowObserver.canvasItemDelegate?.zIndex ?? 0
        let defaultInputNodeIndex = downstreamRowObserver.canvasItemDelegate?.zIndex ?? 0
        let zIndexOfInputNode = downstreamRowObserver.canvasItemDelegate?.zIndex ?? defaultInputNodeIndex
        self.zIndex = max(upstreamRowObserverZIndex, zIndexOfInputNode)
    }
}

extension ConnectedEdgeData: Identifiable {
    var id: NodeRowViewModelId {
        self.downstreamRowObserver.id
    }
}
