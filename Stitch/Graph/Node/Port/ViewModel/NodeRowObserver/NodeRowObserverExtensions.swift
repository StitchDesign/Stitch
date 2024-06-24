//
//  NodeRowObserverExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

// MARK: non-derived data: values, assigned interactions, label, upstream/downstream connection

extension NodeRowObserver {
    @MainActor
    func updateValues(_ newValues: PortValues,
                      activeIndex: ActiveIndex,
                      isVisibleInFrame: Bool,
                      // Used for layer nodes which haven't yet initialized fields
                      isInitialization: Bool = false) {
        // Save these for `postProcessing`
        let oldValues = self.allLoopedValues
        
        // Always update the non-view data in the NodeRowObserver
        self.allLoopedValues = newValues
        
        // Always update "hasLoop", since offscreen node may have an onscreen edge.
        let hasLoop = newValues.hasLoop
        if hasLoop != self.hasLoopedValues {
            self.hasLoopedValues = hasLoop
        }
        
        // Update cached view-specific data: "viewValue" i.e. activeValue
        
        let oldViewValue = self.activeValue // the old cached
        let newViewValue = self.getActiveValue(activeIndex: activeIndex)
        let didViewValueChange = oldViewValue != newViewValue
        
        let isLayerFocusedInPropertySidebar = self.nodeDelegate?.graphDelegate?.layerFocusedInPropertyInspector == self.id.nodeId
        
        /*
         Conditions for forcing fields update:
         1. Is at time of initialization--used for layers, or
         2. Did values change AND visible in frame, or
         3. Is this an input for a layer node that is focused in the property sidebar?
         */
        let shouldUpdate = isInitialization || (didViewValueChange && isVisibleInFrame) || isLayerFocusedInPropertySidebar

        if shouldUpdate {
            self.activeValue = newViewValue

            // TODO: pass in media to here!
            self.activeValueChanged(oldValue: oldViewValue,
                                    newValue: newViewValue)
        }
        
        self.postProcessing(oldValues: oldValues, newValues: newValues)
    }
    
    @MainActor
    func postProcessing(oldValues: PortValues,
                        newValues: PortValues) {
        // Update cached interactions data in graph
        self.updateInteractionNodeData(oldValues: oldValues,
                                       newValues: newValues)
        
        // Update visual color data
        self.updatePortColor()
    }
    
    /// Updates layer selections for interaction patch nodes for perf.
    @MainActor
    func updateInteractionNodeData(oldValues: PortValues,
                                   newValues: PortValues) {
        // Interaction nodes ignore loops of assigned layers and only use the first
        let firstValueOld = oldValues.first
        let firstValueNew = newValues.first
        
        guard let graphDelegate = self.nodeDelegate?.graphDelegate,
              let patch = self.nodeKind.getPatch,
              patch.isInteractionPatchNode,
              self.nodeIOType == .input,
              self.id.portId == 0 else { //, // the "assigned layer" input
            
            // TODO: how was `updateInteractionNodeData` being called with the exact same value for `firstValueOld` and `firstValueNew`?
            // NOTE: Over-updating a dictionary is probably fine, perf-wise; an interaction node's assigned layer is not something that is updated at 120 FPS...
            
//              firstValueOld != firstValueNew else {
            return
        }
        
        // Remove old value from graph state
        if let oldLayerId = firstValueOld?.getInteractionId {
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
        
        if let newLayerId = firstValueNew?.getInteractionId {
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
    
    func getMediaObjects() -> [StitchMediaObject] {
        self.allLoopedValues
            .compactMap { $0.asyncMedia?.mediaObject }
    }
    
    var currentBroadcastChoiceId: NodeId? {
        guard self.nodeKind == .patch(.wirelessReceiver),
              self.id.portId == 0,
              self.nodeIOType == .input else {
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
    
    @MainActor
    func label(_ useShortLabel: Bool = false) -> String {
        switch id.portType {
        case .portIndex(let portId):
            if self.nodeIOType == .input,
               let mathExpr = self.nodeDelegate?.getMathExpression?.getSoulverVariables(),
               let variableChar = mathExpr[safe: portId] {
                return String(variableChar)
            }
            
            let rowDefinitions = self.nodeKind.graphNode?.rowDefinitions(for: userVisibleType) ?? self.nodeKind.rowDefinitions(for: userVisibleType)
            
            // Note: when an input is added (e.g. adding an input to an Add node),
            // the newly-added input will not be found in the rowDefinitions,
            // so we can use an empty string as its label.
            return self.nodeIOType == .input
            ? rowDefinitions.inputs[safe: portId]?.label ?? ""
            : rowDefinitions.outputs[safe: portId]?.label ?? ""
            
        case .keyPath(let keyPath):
            return keyPath.label(useShortLabel)
        }
    }
    
    @MainActor
    func getConnectedUpstreamNode() -> NodeId? {
        guard let upstreamOutputObserver = self.upstreamOutputObserver else {
            return nil
        }
        
        guard let outputPort = upstreamOutputObserver.outputPortViewData else {
            return nil
        }
        
        return outputPort.nodeId
    }
    
    @MainActor
    func getConnectedDownstreamNodes() -> NodeIdSet {
        var nodes = NodeIdSet()
        
        guard let portId = self.id.portId,
              let connectedInputs = self.nodeDelegate?.graphDelegate?.connections
            .get(NodeIOCoordinate(portId: portId,
                                  nodeId: id.nodeId)) else {
            return nodes
        }
        
        connectedInputs.forEach { inputCoordinate in
            guard let node = self.nodeDelegate?.graphDelegate?.getNodeViewModel(inputCoordinate.nodeId),
                  let inputRowObserver = node.getInputRowObserver(for: inputCoordinate.portType),
                  let inputPortViewData = inputRowObserver.inputPortViewData else {
                return
            }
            
            nodes.insert(inputPortViewData.nodeId)
        }
        
        return nodes
    }
    
    /// Same as `createSchema()` but used for layer schema data.
    @MainActor
    func createLayerSchema() -> NodeConnectionType {
        guard let upstreamOutputObserver = self.upstreamOutputObserver else {
            return .values(self.allLoopedValues)
        }
        
        return .upstreamConnection(upstreamOutputObserver.id)
    }
}

extension NodeRowObservers {
    @MainActor
    init(values: PortValuesList,
         kind: NodeKind,
         userVisibleType: UserVisibleType?,
         id: NodeId,
         nodeIO: NodeIO,
         activeIndex: ActiveIndex,
         nodeDelegate: NodeDelegate) {
        self = values.enumerated().map { portId, values in
            NodeRowObserver(values: values,
                            nodeKind: kind,
                            userVisibleType: userVisibleType,
                            id: NodeIOCoordinate(portId: portId, nodeId: id),
                            activeIndex: activeIndex,
                            upstreamOutputCoordinate: nil,
                            nodeIOType: nodeIO,
                            nodeDelegate: nodeDelegate)
        }
    }

    var values: PortValuesList {
        self.map {
            $0.allLoopedValues
        }
    }

    @MainActor
    func updateAllValues(_ newValuesList: PortValuesList,
                         nodeIO: NodeIO,
                         nodeId: NodeId,
                         nodeKind: NodeKind,
                         userVisibleType: UserVisibleType?,
                         nodeDelegate: NodeDelegate,
                         activeIndex: ActiveIndex) {
        
        let oldValues = self.values
        let oldLongestPortLength = oldValues.count
        let newLongestPortLength = newValuesList.count
        let currentObserverCount = self.count

        // Remove view models if loop count decreased
        if newLongestPortLength < oldLongestPortLength {
            // Sub-array can't exceed its current bounds or we get index-out-of-bounds
            // Helpers below will create any missing observers
            let arrayBoundary = Swift.min(newLongestPortLength, currentObserverCount)

            nodeDelegate.portCountShortened(to: arrayBoundary, nodeIO: nodeIO)
        }

        newValuesList.enumerated().forEach { portId, values in
            let observer = self[safe: portId] ??
                // Sometimes observers aren't yet created for nodes with adjustable inputs
                NodeRowObserver(values: values,
                                nodeKind: nodeDelegate.kind,
                                userVisibleType: userVisibleType,
                                id: .init(portId: portId, nodeId: nodeId),
                                activeIndex: .init(.zero),
                                upstreamOutputCoordinate: nil,
                                nodeIOType: nodeIO,
                                nodeDelegate: nodeDelegate)

            // Only update values if there's no upstream connection
            if !observer.upstreamOutputObserver.isDefined {
                observer.updateValues(values,
                                      activeIndex: nodeDelegate.activeIndex,
                                      isVisibleInFrame: nodeDelegate.isVisibleInFrame)
            }
        }
    }
}
