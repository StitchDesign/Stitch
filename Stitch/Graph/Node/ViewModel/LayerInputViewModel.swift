//
//  LayerInputViewModel.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/21/24.
//

import Foundation
import StitchSchemaKit

@Observable
final class NodeDataViewModel {
    // Needed for e.g. group nodes, since a group node may not have an input or output that we can query
    let id: NodeId
    
    var canvasUIData: CanvasItemViewModel
    
//    init(id: NodeId, 
//         canvasUIData: CanvasItemViewModel) {
//        self.id = id
//        self.canvasUIData = canvasUIData
//    }
    
    // TODO: these could be in a smaller class, since some contexts need inputs and outputs but not canvas ui-data etc.
    // Don't need to be private?
    var _inputsObservers: NodeRowObservers = []
    var _outputsObservers: NodeRowObservers = []
        
    // Every single input and output observer should have same node delegate reference
    var nodeDelegate: NodeDelegate? {
        self._inputsObservers.first?.nodeDelegate
    }
    
    init(id: NodeId,
         canvasUIData: CanvasItemViewModel,
         inputs: NodeRowObservers,
         outputs: NodeRowObservers) {
        self.id = id
        self.canvasUIData = canvasUIData
        self._inputsObservers = inputs
        self._outputsObservers = outputs
    }
}

extension NodeIO {
    var toSplitterType: SplitterType {
        switch self {
        case .input:
            return .input
        case .output:
            return .output
        }
    }
}

extension NodeDataViewModel {

    // TODO: which is better -- to expose these as an interface on NodeViewModel only, or both there and here?
    @MainActor
    func getInputRowObserver(_ portId: Int) -> NodeRowObserver? {
            
        if self.nodeDelegate?.kind == .group {
            return self.nodeDelegate?.graphDelegate?
                .getSplitterRowObservers(
                    for: self.id,
                    type: .input)[safe: portId]
        }
        
        // Sometimes observers aren't yet created for nodes with adjustable inputs
        return self._inputsObservers[safe: portId]
    }
    
    @MainActor
    func getOutputRowObserver(_ portId: Int) -> NodeRowObserver? {
        if self.nodeDelegate?.kind == .group {
            return self.nodeDelegate?.graphDelegate?
                .getSplitterRowObservers(for: self.id,
                                         type: .output)[safe: portId]
        }
        
        return self._outputsObservers[safe: portId]
    }
    
    @MainActor
    func updateVisibilityStatus(with newValue: Bool,
                                activeIndex: ActiveIndex) {
                
        // Only relevant for Patch and Group, which use Node
        guard let nodeKind = self.nodeDelegate?.kind else {
            fatalErrorIfDebug()
            return
        }
        
        let oldValue = self.isVisibleInFrame
        if oldValue != newValue {
            self.isVisibleInFrame = newValue

            if nodeKind == .group {
                // Group node needs to mark all input and output splitters as visible
                // Fixes issue for setting visibility on groups
//                let inputsObservers = self.getRowObservers(.input)
                let inputsObservers = self.getRowObservers(.input, nodeKind)
                let outputsObservers = self.getRowObservers(.output, nodeKind)
                let allObservers = inputsObservers + outputsObservers
                allObservers.forEach {
                    $0.canvasUIData?.isVisibleInFrame = newValue
                }
            }

            // Refresh values if node back in frame
            if newValue {
                self.updateInputsAndOutputsUponVisibilityChange(activeIndex)
            }
        }
    }
    
    // This is basically a wrapper for "Are we retrieving inputs/outputs for a
    @MainActor
    func getRowObservers(_ nodeIO: NodeIO,
                         _ nodeKind: NodeKind) -> NodeRowObservers {
        
        if nodeKind == .group {
            return self.nodeDelegate?.graphDelegate?.getSplitterRowObservers(
                for: self.id,
                type: nodeIO.toSplitterType) ?? []
        }
        
        switch nodeIO {
        case .input:
            // Note: this fn is only for patch
            return self._inputsObservers
        case .output:
            return self._outputsObservers
        }
    }
    
    var parentGroupNodeId: NodeId? {
        get {
            self.canvasUIData.parentGroupNodeId
        }
        set(newValue) {
            self.canvasUIData.parentGroupNodeId = newValue
        }
    }
    
    @MainActor
    var isSelected: Bool {
        get {
            self.canvasUIData.isSelected
        }
        set(newValue) {
            self.canvasUIData.isSelected = newValue
        }
    }
    
    var position: CGPoint {
        get {
            self.canvasUIData.position
        }
        set(newValue) {
            self.canvasUIData.position = newValue
        }
    }
    
    var previousPosition: CGPoint {
        get {
            self.canvasUIData.previousPosition
        }
        set(newValue) {
            self.canvasUIData.previousPosition = newValue
        }
    }
    
    var zIndex: Double {
        get {
            self.canvasUIData.zIndex
        }
        set(newValue) {
            self.canvasUIData.zIndex = newValue
        }
    }
    
    var isVisibleInFrame: Bool {
        get {
            self.canvasUIData.isVisibleInFrame
        }
        set(newValue) {
            self.canvasUIData.isVisibleInFrame = newValue
        }
    }
    
    var bounds: NodeBounds {
        get {
            self.canvasUIData.bounds
        }
        set(newValue) {
            self.canvasUIData.bounds = newValue
        }
    }
    
}

