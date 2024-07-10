//
//  NodeRowObserverExtensions.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/17/24.
//

import Foundation
import StitchSchemaKit

// MARK: non-derived data: values, assigned interactions, label, upstream/downstream connection

//extension NodeViewModel {
//    func updateValues(_ newValues: PortValues,
//                      activeIndex: ActiveIndex) {
//        
//    }
//}

extension NodeRowObserver {
    @MainActor
    func updateValues(_ newValues: PortValues) {
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
        if let rowViewModel = self.getVisibleRowViewModel() {
            rowViewModel.didPortValuesUpdate(values: newValues)
        }
        
        self.postProcessing(oldValues: oldValues, newValues: newValues)
    }
    
    @MainActor
    func getVisibleRowViewModel() -> Self.RowViewModelType? {
        guard let node = self.rowViewModel.canvasItemDelegate else {
            fatalErrorIfDebug()
            return nil
        }
        
        return node.isVisibleInFrame ? self.rowViewModel : nil
        
//        return nodeDelegate
//            .getAllCanvasObservers()
//            .filter { $0.isVisibleInFrame }
//            .flatMap { canvasItem in
//                canvasItem.inputViewModels
//                    .filter { $0.rowDelegate?.id == self.id }
//            }
    }
    
    @MainActor var activeValue: PortValue {
        self.rowViewModel.activeValue
    }
    
    @MainActor
    func postProcessing(oldValues: PortValues,
                        newValues: PortValues) {
        // Update cached interactions data in graph
        self.updateInteractionNodeData(oldValues: oldValues,
                                       newValues: newValues)
        
        // Update visual color data
        self.allInputRowViewModels.forEach {
            $0.updatePortColor()
        }
        
        self.allOutputRowViewModels.forEach {
            $0.updatePortColor()
        }
    }
    
    @MainActor
    var allInputRowViewModels: [InputNodeRowViewModel] {
        self.nodeDelegate?.allInputRowViewModels ?? []
    }
    
    @MainActor
    var allOutputRowViewModels: [OutputNodeRowViewModel] {
        self.nodeDelegate?.allOutputRowViewModels ?? []
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
              Self.nodeIOType == .input,
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
    
    @MainActor
    func label(_ useShortLabel: Bool = false) -> String {
        switch id.portType {
        case .portIndex(let portId):
            if Self.nodeIOType == .input,
               let mathExpr = self.nodeDelegate?.getMathExpression?.getSoulverVariables(),
               let variableChar = mathExpr[safe: portId] {
                return String(variableChar)
            }
            
            let rowDefinitions = self.nodeKind.graphNode?.rowDefinitions(for: userVisibleType) ?? self.nodeKind.rowDefinitions(for: userVisibleType)
            
            // Note: when an input is added (e.g. adding an input to an Add node),
            // the newly-added input will not be found in the rowDefinitions,
            // so we can use an empty string as its label.
            return Self.nodeIOType == .input
            ? rowDefinitions.inputs[safe: portId]?.label ?? ""
            : rowDefinitions.outputs[safe: portId]?.label ?? ""
            
        case .keyPath(let keyPath):
            return keyPath.label(useShortLabel)
        }
    }
}

extension Array where Element: NodeRowObserver {
    var values: PortValuesList {
        self.map {
            $0.allLoopedValues
        }
    }
    
    @MainActor
    func updateAllValues(_ newValuesList: PortValuesList,
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

            nodeDelegate.patchNodeViewModel?.portCountShortened(to: arrayBoundary,
                                                                nodeIO: .input)
        }

        newValuesList.enumerated().forEach { portId, values in
            let observer = self[safe: portId] ??
                // Sometimes observers aren't yet created for nodes with adjustable inputs
            Element(values: values,
                    nodeKind: nodeDelegate.kind,
                    userVisibleType: userVisibleType,
                    id: .init(portId: portId, nodeId: nodeId),
                    activeIndex: .init(.zero),
                    nodeRowIndex: portId,
                    upstreamOutputCoordinate: nil,
                    nodeDelegate: nodeDelegate,
                    canvasItemDelegate: nil)

            // Only update values if there's no upstream connection
//            if !observer.upstreamOutputObserver.isDefined {
//                observer.updateValues(values)
//            }
        }
    }
}

extension [InputNodeRowObserver] {
    @MainActor
    init(values: PortValuesList,
         kind: NodeKind,
         userVisibleType: UserVisibleType?,
         id: NodeId,
         nodeIO: NodeIO,
         activeIndex: ActiveIndex,
         nodeRowIndex: Int?,
         nodeDelegate: NodeDelegate,
         canvasItem: CanvasItemViewModel?) {
        self = values.enumerated().map { portId, values in
            Element(values: values,
                    nodeKind: kind,
                    userVisibleType: userVisibleType,
                    id: NodeIOCoordinate(portId: portId, nodeId: id),
                    activeIndex: activeIndex,
                    nodeRowIndex: nodeRowIndex,
                    upstreamOutputCoordinate: nil,
                    nodeDelegate: nodeDelegate,
                    canvasItemDelegate: canvasItem)
        }
    }
}

extension InputNodeRowObserver {
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
    
    /// Same as `createSchema()` but used for layer schema data.
    @MainActor
    func createLayerSchema() -> NodeConnectionType {
        guard let upstreamOutputObserver = self.upstreamOutputObserver else {
            return .values(self.allLoopedValues)
        }
        
        return .upstreamConnection(upstreamOutputObserver.id)
    }
}
