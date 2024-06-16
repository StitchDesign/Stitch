//
//  PortPreferenceData.swift
//  prototype
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

struct EdgeAnchorUpstreamData: Equatable {
    // Port-specific data
    let firstUpstreamObserver: NodeRowObserver
    let lastUpstreamObserver: NodeRowObserver
    
    // Edge-specific data used for calculating Y distance for edge views
    // Optional to support edge dragging
    let firstConnectedUpstreamObserver: NodeRowObserver?
    let lastConnectedUpstreamObserver: NodeRowObserver?
    
    let totalOutputs: Int
}

struct EdgeAnchorDownstreamData: Equatable {
    // Port-specific data
    let firstInputObserver: NodeRowObserver
    let lastInputObserver: NodeRowObserver
    
    // Edge-specific data used for calculating Y distance for edge views
    // Optional to support possible edges for animation
    let firstConnectedInputObserver: NodeRowObserver?
    let lastConectedInputObserver: NodeRowObserver?
}

extension EdgeAnchorUpstreamData {
    @MainActor
    init?(from upstreamRowObserver: NodeRowObserver?,
          connectedDownstreamNode: NodeDelegate?) {
        guard let upstreamRowObserver = upstreamRowObserver,
              let outputsCount = upstreamRowObserver.nodeDelegate?.outputsRowCount,
              let firstUpstreamObserver = upstreamRowObserver.nodeDelegate?.getOutputRowObserver(0),
              let lastUpstreamObserver = upstreamRowObserver.nodeDelegate?.getOutputRowObserver(outputsCount - 1) else {
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
        
        let downstreamInputs = connectedDownstreamNode.inputRowObservers()
        
        // Find top and bottom-most edges from upstream node connecting to this node
        var firstConnectedUpstreamObserver: NodeRowObserver?
        var lastConnectedUpstreamObserver: NodeRowObserver?
        downstreamInputs.forEach{ downstreamInput in
            // Do nothing if no connection from this input
            guard let upstreamToThisInput = downstreamInput.upstreamOutputObserver else {
                return
            }
            
            let isDownstreamInputConnectedToThisNode = upstreamToThisInput.id.nodeId == upstreamRowObserver.id.nodeId
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
    init?(from inputRowObserver: NodeRowObserver,
          upstreamNodeId: NodeId? = nil) {
        guard let inputsCount = inputRowObserver.nodeDelegate?.inputsRowCount,
              let firstInputObserver = inputRowObserver.nodeDelegate?.getInputRowObserver(0),
              let lastInputObserver = inputRowObserver.nodeDelegate?.getInputRowObserver(inputsCount - 1),
              let node = inputRowObserver.nodeDelegate,
              let upstreamConnectedNodeId = upstreamNodeId ?? inputRowObserver.upstreamOutputCoordinate?.nodeId else {
            return nil
        }

        let allInputs = node.inputRowObservers()
        
        // Iterate through inputs at this node to find other connected edges from same upstream node id
        var firstConnectedInputObserver: NodeRowObserver?
        var lastConnectedInputObserver: NodeRowObserver?
        allInputs.forEach { input in
            if input.upstreamOutputCoordinate?.nodeId == upstreamConnectedNodeId {
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
