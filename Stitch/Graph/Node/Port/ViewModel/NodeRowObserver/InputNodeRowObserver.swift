//
//  InputNodeRowObserver.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/4/25.
//

import Foundation
import StitchSchemaKit
import StitchEngine


@Observable
final class InputNodeRowObserver: NodeRowObserver, InputNodeRowCalculatable {
    
    static let nodeIOType: NodeIO = .input

    let id: NodeIOCoordinate
    
    // Data-side for values
    @MainActor
    var allLoopedValues: PortValues = .init()

    // Connected upstream node, if input
    @MainActor
    var upstreamOutputCoordinate: NodeIOCoordinate? {
        didSet(oldValue) {
            self.didUpstreamOutputCoordinateUpdate(oldValue: oldValue)
        }
    }
    
    /// Tracks upstream output row observer for some input. Cached for perf.
    @MainActor
    var upstreamOutputObserver: OutputNodeRowObserver? {
        self.getUpstreamOutputObserver()
    }
    
    // NodeRowObserver holds a reference to its parent, the Node
    @MainActor weak var nodeDelegate: NodeDelegate?

    // MARK: "derived data", cached for UI perf
    
    // Tracks upstream/downstream nodes--cached for perf
    @MainActor var connectedNodes: NodeIdSet = .init()
    
    // Can't be computed for rendering purposes
    @MainActor var hasLoopedValues: Bool = false
    
    @MainActor
    convenience init(from schema: NodePortInputEntity) {
        self.init(values: schema.portData.values ?? [],
                  id: schema.id,
                  upstreamOutputCoordinate: schema.portData.upstreamConnection)
    }
    
    @MainActor
    init(values: PortValues,
         id: NodeIOCoordinate,
         upstreamOutputCoordinate: NodeIOCoordinate?) {
        self.id = id
        self.upstreamOutputCoordinate = upstreamOutputCoordinate
        self.allLoopedValues = values
        self.hasLoopedValues = values.hasLoop
    }
    
    // OUTPUT ONLY
    @MainActor
    func kickOffPulseReversalSideEffects() { }
    
    func updateOutputValues(_ values: [StitchSchemaKit.CurrentPortValue.PortValue]) {
        fatalErrorIfDebug("Should never be called for InputNodeRowObserver")
    }
    
    @MainActor
    var isPulseNodeType: Bool {
        self.allLoopedValues.first?.getPulse.isDefined ?? false
    }
}

extension InputNodeRowObserver {
    // ONLY called by StitchEngine
    @MainActor
    func didInputsUpdate(newValues: PortValues,
                         oldValues: PortValues) {
        
        // If newValues empty, nothing to do
        // Note: this only happens when graph is first opened and connected inputs receive empty outputs?
        guard !newValues.isEmpty else {
            return
        }
                        
        // ASSUMES `newValues: PortValues` HAVE EITHER ALREADY BEEN COERCED OR DIRECTLY-COPIED
        self.updateValues(newValues)
        
        self.inputPostProcessing(oldValues: oldValues, newValues: newValues)
    }
    
    @MainActor
    func didUpstreamOutputCoordinateUpdate(oldValue: NodeIOCoordinate?) {
        let coordinateValueChanged = oldValue != self.upstreamOutputCoordinate
        
        guard let _ = self.upstreamOutputCoordinate else {
            if let oldUpstreamObserver = self.upstreamOutputObserver {
                log("upstreamOutputCoordinate: removing edge")
                
                // Remove edge data
                oldUpstreamObserver.containsDownstreamConnection = false
            }
            
            if coordinateValueChanged {
                // Flatten values
                let newFlattenedValues = self.allLoopedValues.flattenValues()
                self.updateValues(newFlattenedValues)
                // TODO: use input-specific method?
                // self.setValuesInInput(newFlattenedValues)
                
                // Recalculate node once values update
                self.nodeDelegate?.calculate()
            }
            
            return
        }
        
        // Update that upstream observer of new edge
        self.upstreamOutputObserver?.containsDownstreamConnection = true
    }
    
    // Because `private`, needs to be declared in same file(?) as method that uses it
    @MainActor
    private func getUpstreamOutputObserver() -> OutputNodeRowObserver? {
        guard let upstreamCoordinate = self.upstreamOutputCoordinate,
              let upstreamPortId = upstreamCoordinate.portId else {
            return nil
        }

        // Set current upstream observer
        return self.nodeDelegate?.graphDelegate?.getNodeViewModel(upstreamCoordinate.nodeId)?
            .getOutputRowObserver(for: upstreamPortId)
    }
    
    @MainActor
    var hasEdge: Bool {
        self.upstreamOutputCoordinate.isDefined
    }
    
    @MainActor var allRowViewModels: [InputNodeRowViewModel] {
        guard let node = self.nodeDelegate else {
            return []
        }
        
        var inputs = [InputNodeRowViewModel]()
        
        switch node.nodeType {
        case .patch(let patchNode):
            guard let portId = self.id.portId,
                  let patchInput = patchNode.canvasObserver.inputViewModels[safe: portId] else {
                // MathExpression is allowed to have empty inputs
                #if DEV_DEBUG || DEBUG
                if patchNode.patch != .mathExpression {
                    fatalErrorIfDebug()
                }
                #endif
                return []
            }
            
            inputs.append(patchInput)
            
            // Find row view models for group if applicable
            if patchNode.splitterNode?.type == .input {
                // Group id is the only other row view model's canvas's parent ID
                if let groupNodeId = inputs.first?.canvasItemDelegate?.parentGroupNodeId,
                   let groupNode = self.nodeDelegate?.graphDelegate?.getNodeViewModel(groupNodeId)?.nodeType.groupNode {
                    inputs += groupNode.inputViewModels.filter {
                        $0.rowDelegate?.id == self.id
                    }
                }
            }
            
        case .layer(let layerNode):
            guard let keyPath = id.keyPath else {
                fatalErrorIfDebug()
                return []
            }
            
            let port = layerNode[keyPath: keyPath.layerNodeKeyPath]
            inputs.append(port.inspectorRowViewModel)
            
            if let canvasInput = port.canvasObserver?.inputViewModels.first {
                inputs.append(canvasInput)
            }
            
        case .group(let canvas):
            guard let portId = self.id.portId,
                  let groupInput = canvas.inputViewModels[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            
            inputs.append(groupInput)
            
        case .component(let component):
            let canvas = component.canvas
            guard let portId = self.id.portId,
                  let groupInput = canvas.inputViewModels[safe: portId] else {
                fatalErrorIfDebug()
                return []
            }
            
            inputs.append(groupInput)
        }

        return inputs
    }
    
    @MainActor
    func buildUpstreamReference() {
        guard let connectedOutputObserver = self.upstreamOutputObserver else {
            // Upstream values are cached and need to be refreshed if disconnected
            if self.upstreamOutputCoordinate != nil {
                self.upstreamOutputCoordinate = nil
            }
            
            return
        }

        // Check for connected row observer rather than just setting ID--makes for
        // a more robust check in ensuring the connection actually exists
        assertInDebug(
            connectedOutputObserver.id.portId.flatMap { portId in
                self.nodeDelegate?
                    .graphDelegate?
                // Note: we have to retrieve the node for the upstream output
                    .getNode(connectedOutputObserver.id.nodeId)?
                    .getOutputRowObserver(for: portId)
            }.isDefined
        )
        
        // Report to output observer that there's an edge (for port colors)
        // We set this to false on default above
        connectedOutputObserver.containsDownstreamConnection = true
    }
    
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


// Extensions on `NodeRowObserver`, but intended only for input NodeRowObservers
extension NodeRowObserver {
    // TODO: define exclusively on `InputNodeRowObserver`
    @MainActor
    func inputPostProcessing(oldValues: PortValues,
                             newValues: PortValues) {
        
        guard Self.nodeIOType == .input else {
            fatalErrorIfDebug() // called incorrectly
            return
        }
        
        guard let node = self.nodeDelegate,
              let graph = node.graphDelegate,
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
        self.updateInteractionCaches(
            oldValues: oldValues,
            newValues: newValues)
        
        // Potentially update assigned layers
        if node.kind.isLayer,
           oldValues != newValues {
            let layerId = node.id.asLayerNodeId
            graph.assignedLayerUpdated(changedLayerNode: layerId)
        }
        
        // Update view ports
        graph.portsToUpdate.insert(NodePortType.input(self.id))
    }

    
    // When an interaction patch node's first input changes,
    // we may need to update our interactions caches on GraphState.
    // fka `NodeRowObserver.updateInteractionNodeData`
    @MainActor
    func updateInteractionCaches(oldValues: PortValues,
                                 newValues: PortValues) {
        self.nodeDelegate?
            .graphDelegate?
            .updateInteractionCaches(self,
                                     oldValues: oldValues,
                                     newValues: newValues)
    }
}

extension GraphState {
    
    // Better as a method on GraphState, since only the interaction-cachese on GraphState are actually being mutated
    // TODO: some way to read T without the possibility of modifying it?
    @MainActor
    func updateInteractionCaches<T: NodeRowObserver>(_ input: T,
                                                     oldValues: PortValues,
                                                     newValues: PortValues) {
        
        guard T.nodeIOType == .input else {
            fatalErrorIfDebug() // called incorrectly
            return
        }
                        
        guard let patch = input.nodeKind.getPatch,
              patch.isInteractionPatchNode,
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
