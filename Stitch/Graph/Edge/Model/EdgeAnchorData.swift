//
//  PortPreferenceData.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// MARK: - PREFERENCE DATA

/* ----------------------------------------------------------------
 SwiftUI Preference Data: passing data up from children to parent view
 ---------------------------------------------------------------- */

struct EdgeAnchorUpstreamData {
    // Port-specific data
    let firstUpstreamObserver: OutputNodeRowViewModel
    let lastUpstreamObserver: OutputNodeRowViewModel
    
    // Edge-specific data used for calculating Y distance for edge views
    // Optional to support edge dragging
    let firstConnectedUpstreamObserver: OutputNodeRowViewModel?
    let lastConnectedUpstreamObserver: OutputNodeRowViewModel?
    
    let totalOutputs: Int
}

struct EdgeAnchorDownstreamData {
    // Port-specific data
    let firstInputObserver: InputNodeRowViewModel
    let lastInputObserver: InputNodeRowViewModel
    
    // Edge-specific data used for calculating Y distance for edge views
    // Optional to support possible edges for animation
    let firstConnectedInputObserver: InputNodeRowViewModel?
    let lastConectedInputObserver: InputNodeRowViewModel?
}

extension EdgeAnchorUpstreamData {
    @MainActor
    init?(from upstreamRowObserver: OutputNodeRowViewModel?,
          connectedDownstreamNode: NodeDelegate?) {
        guard let upstreamRowObserver = upstreamRowObserver,
              let outputsCount = upstreamRowObserver.canvasItemDelegate?.outputViewModels.count,
              let firstUpstreamObserver = upstreamRowObserver.canvasItemDelegate?.outputViewModels.first,
              let lastUpstreamObserver = upstreamRowObserver.canvasItemDelegate?.outputViewModels[safe: outputsCount - 1] else {
            return nil
        }
        
        guard let connectedDownstreamNode = connectedDownstreamNode else {
            // Hits on edge drag when no eligible input found yet
            self.init(firstUpstreamObserver: firstUpstreamObserver,
                      lastUpstreamObserver: lastUpstreamObserver,
                      firstConnectedUpstreamObserver: nil,
                      lastConnectedUpstreamObserver: nil,
                      totalOutputs: outputsCount)
            return
        }
        
        let downstreamInputs = connectedDownstreamNode.getAllInputsObservers()
        
        // Find top and bottom-most edges from upstream node connecting to this node
        var firstConnectedUpstreamObserver: OutputNodeRowViewModel?
        var lastConnectedUpstreamObserver: OutputNodeRowViewModel?
        downstreamInputs.forEach{ downstreamInput in
            // Do nothing if no connection from this input
            guard let upstreamToThisInput = downstreamInput.upstreamOutputObserver?.allRowViewModels.first(where: { $0.id.isNode }) else {
                return
            }
            
            let isDownstreamInputConnectedToThisNode = upstreamToThisInput.nodeDelegate?.id == upstreamRowObserver.nodeDelegate?.id
            if isDownstreamInputConnectedToThisNode {
                guard firstConnectedUpstreamObserver != nil else {
                    firstConnectedUpstreamObserver = upstreamToThisInput
                    return
                }
                
                // If already a highest input found, overwrite lowest input
                lastConnectedUpstreamObserver = firstConnectedUpstreamObserver
            }
        }
        
        // Should have been at least one connection found
        guard let firstConnectedUpstreamObserver = firstConnectedUpstreamObserver else {
            // Can be hit right after edge disconnection
            self.init(firstUpstreamObserver: firstUpstreamObserver,
                      lastUpstreamObserver: lastUpstreamObserver,
                      firstConnectedUpstreamObserver: nil,
                      lastConnectedUpstreamObserver: nil,
                      totalOutputs: outputsCount)
            return
        }
              
        self.init(firstUpstreamObserver: firstUpstreamObserver,
                  lastUpstreamObserver: lastUpstreamObserver,
                  firstConnectedUpstreamObserver: firstConnectedUpstreamObserver,
                  lastConnectedUpstreamObserver: lastConnectedUpstreamObserver ?? firstConnectedUpstreamObserver,
                  totalOutputs: outputsCount)
    }
}

extension EdgeAnchorDownstreamData {
    @MainActor
    init?(from inputRowObserver: InputNodeRowViewModel,
          upstreamNodeId: CanvasItemId? = nil) {
        guard let inputsCount = inputRowObserver.nodeDelegate?.inputsRowCount,
              let firstInputObserver = inputRowObserver.canvasItemDelegate?.inputViewModels.first,
              let lastInputObserver = inputRowObserver.canvasItemDelegate?.inputViewModels[safe: inputsCount - 1],
              let node = inputRowObserver.nodeDelegate,
              let upstreamConnectedNodeId = upstreamNodeId ?? inputRowObserver.rowDelegate?.upstreamOutputObserver?.nodeRowViewModel?.canvasItemDelegate?.id else {
            return nil
        }

        let allInputs = node.allInputViewModels
        
        // Iterate through inputs at this node to find other connected edges from same upstream node id
        var firstConnectedInputObserver: InputNodeRowViewModel?
        var lastConnectedInputObserver: InputNodeRowViewModel?
        allInputs.forEach { input in
            let upstreamCanvasId = input.rowDelegate?.upstreamOutputObserver?.nodeRowViewModel?.canvasItemDelegate?.id
            if upstreamCanvasId == upstreamConnectedNodeId {
                guard firstConnectedInputObserver != nil else {
                    firstConnectedInputObserver = input
                    return
                }
                
                lastConnectedInputObserver = input
            }
        }
        
        self.init(firstInputObserver: firstInputObserver,
                  lastInputObserver: lastInputObserver,
                  firstConnectedInputObserver: firstConnectedInputObserver,
                  lastConectedInputObserver: lastConnectedInputObserver ?? firstConnectedInputObserver)

    }
}
