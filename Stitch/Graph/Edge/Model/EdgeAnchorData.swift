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
    let firstUpstreamOutput: OutputPortUIViewModel
    let lastUpstreamRowOutput: OutputPortUIViewModel
    
    // Edge-specific data used for calculating Y distance for edge views
    // Optional to support edge dragging
    let firstConnectedUpstreamOutput: OutputPortUIViewModel?
    let lastConnectedUpstreamOutput: OutputPortUIViewModel?
    
    let totalOutputs: Int
}

struct EdgeAnchorDownstreamData {
    // Port-specific data
    let firstInput: InputPortUIViewModel
    let lastInput: InputPortUIViewModel
    
    // TODO: clearer names for what these really are
    // Edge-specific data used for calculating Y distance for edge views
    let firstConnectedInput: InputPortUIViewModel
    let lastConectedInput: InputPortUIViewModel
}

extension EdgeAnchorUpstreamData {
    @MainActor
    init?(from upstreamPortUIViewModels: [OutputPortUIViewModel],
          upstreamNodeId: NodeId,
          inputRowViewModelsOnDownstreamNode: [InputNodeRowViewModel]) {
        
        let outputsCount = upstreamPortUIViewModels.count
        
        guard let firstUpstreamOutput = upstreamPortUIViewModels.first,
              let lastUpstreamOutput = upstreamPortUIViewModels.last else {
            fatalErrorIfDebug()
            return nil
        }
                
        // Find top and bottom-most edges from upstream node connecting to this node
        var firstConnectedUpstreamOutput: OutputPortUIViewModel?
        var lastConnectedUpstreamOutput: OutputPortUIViewModel?
        
        inputRowViewModelsOnDownstreamNode.forEach { downstreamInput in
            
            if let upstreamToThisInput = downstreamInput.rowDelegate?.upstreamOutputObserver?.rowViewModelForCanvasItemAtThisTraversalLevel,
//               upstreamToThisInput.nodeDelegate?.id == upstreamNodeId {
               upstreamToThisInput.id.nodeId == upstreamNodeId {
                
                if firstConnectedUpstreamOutput != nil {
                    // If already a highest input found, overwrite lowest input
                    lastConnectedUpstreamOutput = firstConnectedUpstreamOutput
                } else {
                    firstConnectedUpstreamOutput = upstreamToThisInput.portUIViewModel
                }
            }
        }
              
        self.init(firstUpstreamOutput: firstUpstreamOutput,
                  lastUpstreamRowOutput: lastUpstreamOutput,
                  firstConnectedUpstreamOutput: firstConnectedUpstreamOutput,
                  lastConnectedUpstreamOutput: lastConnectedUpstreamOutput ?? firstConnectedUpstreamOutput,
                  totalOutputs: outputsCount)
    }
}

extension EdgeAnchorDownstreamData {
    // Actually want a list of input-port-ui-VMs
    @MainActor
    init?(from inputRowViewModel: InputNodeRowViewModel,
          // nil for EdgeFromDraggedOutputView
          // non-nil for ConnectedEdge data
          // but we have an alternative/default, so should instead provide that
          upstreamNodeId: CanvasItemId? = nil) {
        
        guard let canvas = inputRowViewModel.canvasItemDelegate else {
            fatalErrorIfDebug()
            return nil
        }
                
        guard let firstInputObserver = canvas.inputViewModels.first?.portUIViewModel,
              let lastInputObserver = canvas.inputViewModels.last?.portUIViewModel,
              
                // You probably should not yet have an upstream connected node?
                let upstreamConnectedNodeId: CanvasItemId = upstreamNodeId ?? inputRowViewModel.rowDelegate?.upstreamOutputObserver?.rowViewModelForCanvasItemAtThisTraversalLevel?.canvasItemDelegate?.id else {
            return nil
        }
        
        // Iterate through inputs at this node to find other connected edges from same upstream node id
        var firstConnectedInputObserver: InputPortUIViewModel?
        var lastConnectedInputObserver: InputPortUIViewModel?
        
        canvas.inputViewModels.forEach { input in
            // TODO: this line is crazy... we're checking a row view model's underlying row observer for whether it's actually a canvas item; can we somehow how a row observer / view model for an inspector here? That should be impossible.
            let upstreamCanvasId: CanvasItemId? = input.rowDelegate?.upstreamOutputObserver?.rowViewModelForCanvasItemAtThisTraversalLevel?.canvasItemDelegate?.id
            if upstreamCanvasId == upstreamConnectedNodeId {
                guard firstConnectedInputObserver != nil else {
                    firstConnectedInputObserver = input.portUIViewModel
                    return
                }
                
                lastConnectedInputObserver = input.portUIViewModel
            }
        }
        
        guard let firstConnectedInputObserver = firstConnectedInputObserver else {
            return nil
        }
        
        self.init(firstInput: firstInputObserver,
                  lastInput: lastInputObserver,
                  firstConnectedInput: firstConnectedInputObserver,
                  lastConectedInput: lastConnectedInputObserver ?? firstConnectedInputObserver)

    }
}
