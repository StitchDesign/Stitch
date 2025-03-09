//
//  NodeRowObserverExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit
import StitchEngine

// MARK: non-derived data: values, assigned interactions, label, upstream/downstream connection

extension NodeRowObserver {
    
    /*
     Note: StitchEngine's `setValuesInInput` has already updated an InputRowObserver's `allLoopedValues` by the time `updateValues` is called, therefore `allLoopedValues` already reflects "new values", so we must rely on the explicitly passed-in `oldValues`
     TODO: separate `updateValues` functions for InputNodeRowObserver vs OutputNodeRowObserver, since `oldValues` only relevant for input updates' post-processing?
     */
    @MainActor
    func updateValues(_ newValues: PortValues,
                      oldValues: PortValues? = nil)
    {
        // Check if this port is for a packed layer input but the set mode is unpacked
        // Valid scenarios here--we use input row observer getters for all-up value getting
        if let layerId = self.id.keyPath,
           layerId.portType == .packed,
           let layerNode = self.nodeDelegate?.layerNodeViewModel {
            let layerInputPort = layerNode[keyPath: layerId.layerInput.layerNodeKeyPath]
            
            if let unpackedObserver = layerInputPort.unpackedObserver {
                log("NodeRowObserver.updateValues: will update unpacked values")
                unpackedObserver.updateValues(from: newValues,
                                              layerNode: layerNode)
                
                // Exit so we don't update this packed row observer unnecessarily
                return
            }
        }
        
        // Save these for `postProcessing`
        let oldValues = oldValues ?? self.allLoopedValues
                
        // Always update the non-view data in the NodeRowObserver
        self.allLoopedValues = newValues
                
        // Always update "hasLoop", since offscreen node may have an onscreen edge.
        let hasLoop = newValues.hasLoop
        if hasLoop != self.hasLoopedValues {
            self.hasLoopedValues = hasLoop
        }
        
        self.postProcessing(oldValues: oldValues, newValues: newValues)
        
        self.didValuesUpdate()
    }
    
    @MainActor
    var userVisibleType: UserVisibleType? {
        self.nodeDelegate?.userVisibleType
    }
    
    /// Updates port view models when the backend port observer has been updated.
    /// Also invoked when nodes enter the viewframe incase they need to be udpated.
    @MainActor
//    func updatePortViewModels(_ graph: GraphState) {
    func updatePortViewModels(_ graph: any GraphCalculatable) {
        
        // TODO: this actually works? We don't have to extend the GraphCalculatable protocol to have `visibleCanvasIds`, `selectedSidebarLayers`, `isFullScreenMode` and `groupNodeFocused`? ... Swift is tracking the concrete type?
        guard let graph = graph as? GraphState,
              let document = graph.documentDelegate else {
            log("updatePortViewModels: could not ")
            return
        }
        
        guard let node: NodeViewModel = self.nodeDelegate else {
            // Should this be a fatalError?
//            fatalErrorIfDebug("updatePortViewModels: no node delegate")
            log("updatePortViewModels: no node delegate")
            return
        }
        
        guard node.isVisibleInFrame(graph.visibleCanvasIds,
                                    graph.selectedSidebarLayers) else {
            // Node not visible, so nothing to do
            return
        }
        
        let visibleRowViewModels = self.getVisibleRowViewModels(
            visibleCanvasIds: graph.visibleCanvasIds,
            isFullScreenMode: document.isFullScreenMode,
            groupNodeFocused: document.groupNodeFocused?.groupNodeId)
        
        visibleRowViewModels.forEach { rowViewModel in
            rowViewModel.didPortValuesUpdate(values: self.allLoopedValues)
        }
    }
    
    // Just reads GraphState, does not modify it?
    @MainActor
    func getVisibleRowViewModels(visibleCanvasIds: CanvasItemIdSet,
                                 isFullScreenMode: Bool,
                                 groupNodeFocused: NodeId?) -> [Self.RowViewModelType] {
        // Make sure we're not in full screen mode
//        guard !graph.isFullScreenMode else {
        guard !isFullScreenMode else {
            return []
        }
        
        return self.allRowViewModels.filter { rowViewModel in
            
            switch rowViewModel.id.graphItemType {
                
            // A row for a layer inspector is visible just if layer inspector is open
            case .layerInspector:
                
                // TODO: why can't we the proper condition here? Why must we always return `true`? For perf, we only want to update inspector UI-fields if that inspector is open and this row observer's layer is actually focused; otherwise it's same as if we're updating an off-screen node
                // let showsLayerInspector = graph.graphUI.showsLayerInspector
                // let layerFocused = graph.sidebarSelectionState.all.contains(rowViewModel.id.nodeId)
                // return showsLayerInspector && layerFocused
                return true
                
                
            case .node:
                
                guard let canvas = rowViewModel.canvasItemDelegate else {
                    log("Had row view model for canvas item but no canvas item delegate")
                    return false
                }
                
//                let isVisibleInCurrentGroup = canvas.isVisibleInFrame(graph) && canvas.parentGroupNodeId == graph.groupNodeFocused
                let isVisibleInCurrentGroup = canvas.isVisibleInFrame(visibleCanvasIds) && canvas.parentGroupNodeId == groupNodeFocused
             
                // always update group node, whose row view models don't otherwise update
                let isGroupNode = canvas.nodeDelegate?.nodeType.groupNode.isDefined ?? false
                   
                return isVisibleInCurrentGroup || isGroupNode
            }
        }
    }
    
    @MainActor
    func getActiveValue(activeIndex: ActiveIndex) -> PortValue {
        self.allLoopedValues[safe: activeIndex.adjustedIndex(self.allLoopedValues.count)] ?? .none
    }
    
    @MainActor
    func postProcessing(oldValues: PortValues,
                        newValues: PortValues) {

        // Update cached interactions data in graph
        self.updateInteractionNodeData(oldValues: oldValues,
                                       newValues: newValues)
        
        // Update visual color data
        self.allRowViewModels.forEach {
            $0.updatePortColor()
        }
    }
    
    /// Updates layer selections for interaction patch nodes for perf.
    @MainActor
    func updateInteractionNodeData(oldValues: PortValues,
                                   newValues: PortValues) {
        
        // Interaction nodes ignore loops of assigned layers and only use the first
        // Note: may be nil when first initializing the graph
        let firstValueOld = oldValues.first
        let firstValueNew = newValues.first
               
        guard let graphDelegate = self.nodeDelegate?.graphDelegate,
              let patch = self.nodeKind.getPatch,
              patch.isInteractionPatchNode,
              Self.nodeIOType == .input,
              self.id.portId == 0 else { //, // the "assigned layer" input
            return
        }
        
        if let firstValueOld = firstValueOld,
            case let .assignedLayer(oldLayerId) = firstValueOld {
            // Note: `.assignedLayer(nil)` is for when the interaction patch has no assigned layer
            if let oldLayerId = oldLayerId {
                switch patch {
                case .dragInteraction:
                    graphDelegate.dragInteractionNodes.removeValue(forKey: oldLayerId)
                case .pressInteraction:
                    graphDelegate.pressInteractionNodes.removeValue(forKey: oldLayerId)
                case .scrollInteraction:
                    graphDelegate.scrollInteractionNodes.removeValue(forKey: oldLayerId)
                default:
                    fatalErrorIfDebug()
                }
            }
        }
        
        // Remove old value from graph state
        // Note: can be nil when first initializing the graph
        if let firstValueNew = firstValueNew,
            case let .assignedLayer(newLayerId) = firstValueNew {
            
            // Note: `.assignedLayer(nil)` is for when the interaction patch has no assigned layer
            if let newLayerId = newLayerId {
                switch patch {
                case .dragInteraction:
                    var currentIds = graphDelegate.dragInteractionNodes.get(newLayerId) ?? NodeIdSet()
                    currentIds.insert(self.id.nodeId)
                    graphDelegate.dragInteractionNodes.updateValue(currentIds, forKey: newLayerId)
                case .pressInteraction:
                    var currentIds = graphDelegate.pressInteractionNodes.get(newLayerId) ?? NodeIdSet()
                    currentIds.insert(self.id.nodeId)
                    graphDelegate.pressInteractionNodes.updateValue(currentIds, forKey: newLayerId)
                case .scrollInteraction:
                    var currentIds = graphDelegate.scrollInteractionNodes.get(newLayerId) ?? NodeIdSet()
                    currentIds.insert(self.id.nodeId)
                    graphDelegate.scrollInteractionNodes.updateValue(currentIds, forKey: newLayerId)
                default:
                    fatalErrorIfDebug()
                }
            }
        }
    }
    
    @MainActor
    func getComputedMediaObjects() -> [StitchMediaObject] {
        self.nodeDelegate?.ephemeralObservers?.compactMap {
            ($0 as? MediaEvalOpObservable)?.computedMedia?.mediaObject
        } ?? []
    }
    
    // MARK: change args here if working
    @MainActor
    func label(useShortLabel: Bool = false,
               node: NodeViewModel,
               coordinate: Coordinate,
               graph: GraphState) -> String {     
        /*
         Two scenarios re: a Group Node and its splitters:
         
         1. We are looking at the Group Node itself; so we want to use its underlying group node input- and output-splitters' titles as labels for the group node's rows
         
         2. We are INSIDE THE GROUP NODE, looking at its input- and output-splitters at that traversal level; so we do not use the splitters' titles as labels
         */        
        if node.kind == .group {
            // Cached values which get underlying splitter node's title
            guard let labelFromSplitter = graph.groupPortLabels.get(coordinate) else {
                // Could be loading initially
//                fatalErrorIfDebug()
                return ""
            }

            // Don't show label on group node's input/output row unless it is custom
            if labelFromSplitter == Patch.splitter.defaultDisplayTitle() {
                return ""
            }
                        
            return labelFromSplitter
        }
        
        switch self.id.portType {
        case .portIndex(let portId):
            if Self.nodeIOType == .input,
               let mathExpr = node.getMathExpression?.getSoulverVariables(),
               let variableChar = mathExpr[safe: portId] {
                return String(variableChar)
            }
            
            let rowDefinitions = node.kind.graphNode?.rowDefinitions(for: userVisibleType) ?? node.kind.rowDefinitions(for: userVisibleType)
            
            // Note: when an input is added (e.g. adding an input to an Add node),
            // the newly-added input will not be found in the rowDefinitions,
            // so we can use an empty string as its label.
            return Self.nodeIOType == .input
            ? rowDefinitions.inputs[safe: portId]?.label ?? ""
            : rowDefinitions.outputs[safe: portId]?.label ?? ""
            
        case .keyPath(let keyPath):
            return keyPath.layerInput.label(useShortLabel: useShortLabel)
        }
    }
}

extension [InputNodeRowObserver] {
    @MainActor
    init(values: PortValuesList,
         id: NodeId,
         nodeIO: NodeIO,
         nodeDelegate: NodeDelegate) {
        self = values.enumerated().map { portId, values in
            Element(values: values,
                    id: NodeIOCoordinate(portId: portId, nodeId: id),
                    upstreamOutputCoordinate: nil,
                    nodeDelegate: nodeDelegate)
        }
    }
}

extension InputNodeRowObserver {
    @MainActor
    var currentBroadcastChoiceId: NodeId? {
        guard self.nodeKind == .patch(.wirelessReceiver),
              self.id.portId == 0,
              Self.nodeIOType == .input else {
            // log("NodeRowObserver: currentBroadcastChoice: did not have wireless node: returning nil")
            return nil
        }
        
        // the id of the connected wireless broadcast node
        // TODO: why was there an `upstreamOutputCoordinate` but not a `upstreamOutputObserver` ?
        //        let wirelessBroadcastId = self.upstreamOutputObserver?.id.nodeId
        let wirelessBroadcastId = self.upstreamOutputCoordinate?.nodeId
        // log("NodeRowObserver: currentBroadcastChoice: wirelessBroadcastId: \(wirelessBroadcastId)")
        return wirelessBroadcastId
    }
}
