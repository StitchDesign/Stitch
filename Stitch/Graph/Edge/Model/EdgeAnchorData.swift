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
    
    // Edge-specific data used for calculating Y distance for edge views
    let firstConnectedInput: InputPortUIViewModel
    let lastConectedInput: InputPortUIViewModel
}

extension EdgeAnchorUpstreamData {
    @MainActor
//    init?(from upstreamRowObserver: OutputNodeRowViewModel,
    init?(from upstreamOutputRowViewModel: OutputNodeRowViewModel,
          connectedDownstreamNode: NodeViewModel) {
        
        guard let upstreamCanvasItem = upstreamOutputRowViewModel.canvasItemDelegate else {
            return nil
        }
        
        let outputsCount = upstreamCanvasItem.outputViewModels.count
        
        guard let firstUpstreamOutput = upstreamCanvasItem.outputViewModels.first?.portUIViewModel,
              let lastUpstreamOutput = upstreamCanvasItem.outputViewModels[safe: outputsCount - 1]?.portUIViewModel else {
            return nil
        }
        
        let downstreamInputs = connectedDownstreamNode.allInputRowViewModels
        
        // Find top and bottom-most edges from upstream node connecting to this node
        var firstConnectedUpstreamOutput: OutputPortUIViewModel?
        var lastConnectedUpstreamOutput: OutputPortUIViewModel?
        downstreamInputs.forEach { downstreamInput in
            // Do nothing if no connection from this input
            guard let upstreamToThisInput = downstreamInput.rowDelegate?.upstreamOutputObserver?.nodeRowViewModel
                else {
                return
            }
            
            let isDownstreamInputConnectedToThisNode = upstreamToThisInput.nodeDelegate?.id == upstreamCanvasItem.id.nodeId
            if isDownstreamInputConnectedToThisNode {
                guard firstConnectedUpstreamOutput != nil else {
                    firstConnectedUpstreamOutput = upstreamToThisInput.portUIViewModel
                    return
                }
                
                // If already a highest input found, overwrite lowest input
                lastConnectedUpstreamOutput = firstConnectedUpstreamOutput
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
          upstreamNodeId: CanvasItemId? = nil) {
        
        guard let canvas = inputRowViewModel.canvasItemDelegate else {
            return nil
        }
        
        let inputsCount = canvas.inputViewModels.count
        
        guard let firstInputObserver = canvas.inputViewModels.first?.portUIViewModel,
              let lastInputObserver = canvas.inputViewModels[safe: inputsCount - 1]?.portUIViewModel,
              let upstreamConnectedNodeId = upstreamNodeId ?? inputRowViewModel.rowDelegate?.upstreamOutputObserver?.nodeRowViewModel?.canvasItemDelegate?.id else {
            return nil
        }
        
        // Iterate through inputs at this node to find other connected edges from same upstream node id
        var firstConnectedInputObserver: InputPortUIViewModel?
        var lastConnectedInputObserver: InputPortUIViewModel?
        canvas.inputViewModels.forEach { input in
            // TODO: this line is crazy... we're checking a row view model's underlying row observer for whether it's actually a canvas item; can we somehow how a row observer / view model for an inspector here? That should be impossible.
            let upstreamCanvasId = input.rowDelegate?.upstreamOutputObserver?.nodeRowViewModel?.canvasItemDelegate?.id
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
