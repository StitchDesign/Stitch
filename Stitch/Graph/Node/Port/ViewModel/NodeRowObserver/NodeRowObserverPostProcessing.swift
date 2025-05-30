//
//  NodeRowObserverPostProcessing.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/31/25.
//

import Foundation
import StitchSchemaKit
import StitchEngine

// POST-PROCESSING = "This input's or output's values change. What else needs to happen in response?"

// MARK: INPUT POST-PROCESSING

// Extensions on `NodeRowObserver`, but intended only for input NodeRowObservers
extension NodeRowObserver {
    // TODO: define exclusively on `InputNodeRowObserver`
    @MainActor
    func inputPostProcessing(oldValues: PortValues,
                             newValues: PortValues,
                             // Can this graph ever be other than than visible graph?
                             graph: GraphState) {
        
        guard Self.nodeIOType == .input else {
            fatalErrorIfDebug() // called incorrectly
            return
        }
        
        guard let node = graph.getNode(self.id.nodeId),
              let document = graph.documentDelegate else {
            return
        }
        
        // If we changed a camera direction/orientation input on a camera-using node (Camera or RealityKit),
        // then we may need to update GraphState.cameraSettings, CameraFeedManager etc.
        
        // Potentially update camera settings
        if node.kind.usesCamera,
           let originalValue = oldValues.first,
           let newValue = newValues.first {
            document.cameraInputChange(
                input: self.id,
                originalValue: originalValue,
                coercedValue: newValue)
        }
        
        // Potentially update interactiojn data
        if let patch = node.kind.getPatch,
           patch.isInteractionPatchNode {
            graph.updateInteractionCaches(self,
                                          oldValues: oldValues,
                                          newValues: newValues,
                                          patch: patch)
        }
        
        // Potentially update assigned layers
        if node.kind.isLayer,
           oldValues != newValues {
            let layerId = node.id.asLayerNodeId
            graph.assignedLayerUpdated(changedLayerNode: layerId)
        }
        
        // Update view ports
        graph.portsToUpdate.insert(NodePortType.input(self.id))
    }
}

extension GraphState {

    // When an interaction patch node's first input changes,
    // we may need to update our interactions caches on GraphState.
    // fka `NodeRowObserver.updateInteractionNodeData`
    
    // Better as a method on GraphState, since only the interaction-cachese on GraphState are actually being mutated
    // TODO: some way to read T without the possibility of modifying it?
    @MainActor
    func updateInteractionCaches<T: NodeRowObserver>(_ input: T,
                                                     oldValues: PortValues,
                                                     newValues: PortValues,
                                                     patch: Patch) {
        
        guard T.nodeIOType == .input else {
            fatalErrorIfDebug() // called incorrectly
            return
        }
                        
        guard patch.isInteractionPatchNode,
              input.id.portId == 0 else {
            return
        }
        
        // Interaction nodes ignore loops of assigned layers and only use the first value
        // Note: may be nil when first initializing the graph; that's okay
        let firstValueOld = oldValues.first
        let firstValueNew = newValues.first
        
        guard firstValueOld != firstValueNew else {
            return
        }
        
        let graph = self
        let nodeId = input.id.nodeId
        
            
        if let firstValueOld = firstValueOld,
            case let .assignedLayer(oldLayerId) = firstValueOld {
            // Note: `.assignedLayer(nil)` is for when the interaction patch has no assigned layer
            if let oldLayerId = oldLayerId {
                switch patch {
                case .dragInteraction:
                    if graph.dragInteractionNodes.keys.contains(oldLayerId) {
                        graph.dragInteractionNodes.removeValue(forKey: oldLayerId)
                    }
                case .pressInteraction:
                    if graph.pressInteractionNodes.keys.contains(oldLayerId) {
                        graph.pressInteractionNodes.removeValue(forKey: oldLayerId)
                    }
                case .scrollInteraction:
                    if graph.scrollInteractionNodes.keys.contains(oldLayerId) {
                        graph.scrollInteractionNodes.removeValue(forKey: oldLayerId)
                    }
                default:
                    fatalErrorIfDebug()
                }
            }
        }
        
        if let firstValueNew = firstValueNew,
            case let .assignedLayer(newLayerId) = firstValueNew {
            // Note: `.assignedLayer(nil)` is for when the interaction patch has no assigned layer
            if let newLayerId = newLayerId {
                switch patch {
                case .dragInteraction:
                    var currentIds = graph.dragInteractionNodes.get(newLayerId) ?? NodeIdSet()
                    currentIds.insert(nodeId)
                    if graph.dragInteractionNodes.get(newLayerId) != currentIds {
                        graph.dragInteractionNodes.updateValue(currentIds, forKey: newLayerId)
                    }
                case .pressInteraction:
                    var currentIds = graph.pressInteractionNodes.get(newLayerId) ?? NodeIdSet()
                    currentIds.insert(nodeId)
                    if graph.pressInteractionNodes.get(newLayerId) != currentIds {
                        graph.pressInteractionNodes.updateValue(currentIds, forKey: newLayerId)
                    }
                case .scrollInteraction:
                    var currentIds = graph.scrollInteractionNodes.get(newLayerId) ?? NodeIdSet()
                    currentIds.insert(nodeId)
                    if graph.scrollInteractionNodes.get(newLayerId) != currentIds {
                        graph.scrollInteractionNodes.updateValue(currentIds, forKey: newLayerId)
                    }
                default:
                    fatalErrorIfDebug()
                }
            }
        }
    }
}

// MARK: OUTPUT POST-PROCESSING

extension NodeRowObserver {
    @MainActor
    func outputPostProcessing(_ graph: GraphState) {        
        guard Self.nodeIOType == .output else {
            fatalErrorIfDebug()
            return
        }
        
        self.updatePulsedOutputsForThisGraphStep(graph)
        
        // TODO: do we need to do this or not?
        // graph.portsToUpdate.insert(.allOutputs(node.id))
    }
    
    // fka `didValuesUpdate`; but only actually used for pulse reversion
    @MainActor
    private func updatePulsedOutputsForThisGraphStep(_ graph: GraphState) {
        
        // TODO: should be by output-coordinate + loop-index, not just output-coordinate?
        if self.allLoopedValues.didSomeLoopIndexPulse(graph.graphStepState.graphTime) {
            graph.pulsedOutputs.insert(self.id)
        }
    }
}


extension PortValues {
    func didSomeLoopIndexPulse(_ graphTime: TimeInterval) -> Bool {
        self.contains { $0.getPulse?.shouldPulse(graphTime) ?? false }
    }
}

