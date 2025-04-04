//
//  NodeViewModelNodeCalculatable.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation
import SwiftUI
import StitchEngine
import StitchSchemaKit

extension NodeViewModel: NodeCalculatable {
    typealias NodeMediaEphemeralObservable = MediaViewModel
    
    var inputsObservers: [InputNodeRowObserver] {
        get {
            self.getAllInputsObservers()
        }
        set(newValue) {
            self.patchNode?.inputsObservers = newValue
        }
    }
    
    var outputsObservers: [OutputNodeRowObserver] {
        get {
            self.getAllOutputsObservers()
        }
        set(newValue) {
            self.patchNode?.outputsObservers = newValue
        }
    }
    
    @MainActor
    func getAllMediaObservers() -> [MediaViewModel]? {
        if let layerNode = self.layerNode {
            return layerNode.previewLayerViewModels.map { $0.mediaViewModel }
        }
        
        if let mediaEvalOpObservers = self.ephemeralObservers as? [MediaEvalOpViewable] {
            return mediaEvalOpObservers.map(\.mediaViewModel)
        }
        
        return nil
    }
    
    @MainActor
    func getMediaObservers(port: NodeIOCoordinate) -> [MediaViewModel]? {
        guard let allMediaObservers = self.getAllMediaObservers() else {
            return nil
        }
            
        switch self.kind {
        case .patch(let patch) where patch == .loopBuilder:
            // Edge case for loop builder which has ephemeral objects for each port, rather than a loop for one port
            guard let portIndex = port.portId else {
                fatalErrorIfDebug()
                return nil
            }
            
            guard let mediaByPort = allMediaObservers[safe: portIndex] else {
                return nil
            }
            
            return [mediaByPort]
            
        default:
            return allMediaObservers
        }
    }
    
    @MainActor
    var isComponentOutputSplitter: Bool {
        let isNodeInComponent = !(self.graphDelegate?.saveLocation.isEmpty ?? true)
        return self.splitterType == .output && isNodeInComponent
    }
        
    @MainActor
    var inputsValuesList: PortValuesList {
        switch self.nodeType {
        case .patch(let patch):
            return patch.inputsObservers.map { $0.allLoopedValues }
        case .layer(let layer):
            return layer.getSortedInputPorts().map { inputPort in
                inputPort.allLoopedValues
            }
        case .group(let canvas):
            return canvas.inputViewModels.compactMap {
                $0.rowDelegate?.allLoopedValues
            }
        case .component(let componentData):
            return componentData.canvas.inputViewModels.compactMap {
                $0.rowDelegate?.allLoopedValues
            }
        }
    }
    
    @MainActor func updateInputMedia(inputCoordinate: NodeIOCoordinate,
                                     mediaList: [GraphMediaValue?]) {
        switch self.nodeType {
        case .patch(let patchNode) where patchNode.patch == .loopBuilder:
            if let mediaObservers = self.getMediaObservers(port: inputCoordinate) {
                for (media, mediaObserver) in zip(mediaList, mediaObservers) {
                    if mediaObserver.inputMedia != media {
                        mediaObserver.inputMedia = media
                    }
                }
            }
            
        case .layer(let layerNode):
            // Assigns media to top-level layer node. Logic at layer eval handles the business of assigning media to specific layer view models. Methods called here are populating downstream layer data before all upstream nodes to layers are finished calling.
            layerNode.mediaList = mediaList
            
        default:
            return
        }
    }
    
    /// Updates computed media ephemeral objects after eval completes.
    @MainActor func updateMediaAfterEval(mediaList: [GraphMediaValue?]) {
        guard let mediaObservers = self.getAllMediaObservers() else {
            return
        }

        switch self.kind {
        case .patch(let patch) where patch == .loopBuilder:
            // Edge case: one observable for each port index, so we lengthen media list to match ports
            let lengthenedMediaList = mediaList.lengthenArray(mediaObservers.count)
            Self.zipMediaIntoObservers(mediaList: lengthenedMediaList,
                                       mediaObservers: mediaObservers)
            
        default:
            // Default case: loop of observables for one port index
            Self.zipMediaIntoObservers(mediaList: mediaList,
                                       mediaObservers: mediaObservers)
        }
    }
    
    @MainActor
    private static func zipMediaIntoObservers(mediaList: [GraphMediaValue?],
                                              mediaObservers: [MediaViewModel]) {
        for (media, ephemeralObserver) in zip(mediaList, mediaObservers) {
            if ephemeralObserver.computedMedia != media {
                ephemeralObserver.computedMedia = media
            }
        }
    }
    
    /*
     After we eval a node, we sets its current inputs to be its previous inputs,
     so that we know we've run the node once,
     and so that we won't run the node again until at least one of the inputs has changed
    
     If unable to run eval for a node (e.g. because it is one of the layer nodes that does not support node eval),
     return `nil` rather than an empty list of inputs.
     */
    @MainActor func evaluate() -> EvalResult? {
        switch self.nodeType {
        case .patch(let patchNodeViewModel):
            // NodeKind.evaluate is our legacy eval caller, cheeck for those first
            if let eval = patchNodeViewModel.patch.evaluate {
                let oldStyleResult = eval.runEvaluation(node: self)
                
                // Result of evaluation should NEVER be an empty list;
                // can happen e.g. when we improperly migrate a node's nodeType
                #if DEV_DEBUG
                oldStyleResult.debugCrashIfAnyOutputLoopEmpty()
                #endif
                return oldStyleResult
            }

            // New-style eval which doesn't require filling out a switch statement
            guard let nodeType = self.kind.graphNode else {
                fatalErrorIfDebug()
                return nil
            }
            
            let newStyleResult = nodeType.evaluate(node: self)
            
            #if DEV_DEBUG
            newStyleResult?.debugCrashIfAnyOutputLoopEmpty()
            #endif
            
            return newStyleResult
        
        case .layer(let layerNodeViewModel):
            // Only a handful of layer nodes have node evals
            if let eval = layerNodeViewModel.layer.evaluate {
                let result = eval.runEvaluation(node: self)
                #if DEV_DEBUG
                result.debugCrashIfAnyOutputLoopEmpty()
                #endif
                return result
            } else {
                return nil
            }
            
        case .component(let component):
            return component.evaluate()
            
        case .group:
            fatalErrorIfDebug()
            return nil
        }
    }
    
    @MainActor
    func inputsWillUpdate(values: PortValuesList) {
        // update cache for longest loop length
        self.longestLoopLength = self.kind.determineMaxLoopCount(from: values)
        
        // Updates preview layers if layer specified
        // Must be before runEval check below since most layers don't have eval!
        self.layerNode?.didValuesUpdate(newValuesList: values)
    }
    
    @MainActor
    var isGroupNode: Bool {
        self.kind == .group
    }
}


extension EvalResult {
    func debugCrashIfAnyOutputLoopEmpty() {
        if self.outputsValues.first(where: { $0.isEmpty }).isDefined {
            fatalErrorIfDebug()
        }
    }
}
