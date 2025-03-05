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
    
    @MainActor
    func didValuesUpdate() { }
    
    func updateOutputValues(_ values: [StitchSchemaKit.CurrentPortValue.PortValue]) {
        fatalErrorIfDebug("Should never be called for InputNodeRowObserver")
    }
    
    @MainActor
    var isPulseNodeType: Bool {
        self.allLoopedValues.first?.getPulse.isDefined ?? false
    }
}

extension InputNodeRowObserver {
    @MainActor
    func didUpstreamOutputCoordinateUpdate(oldValue: NodeIOCoordinate?) {
        let coordinateValueChanged = oldValue != self.upstreamOutputCoordinate
        
        guard let upstreamOutputCoordinate = self.upstreamOutputCoordinate else {
            if let oldUpstreamObserver = self.upstreamOutputObserver {
                log("upstreamOutputCoordinate: removing edge")
                
                // Remove edge data
                oldUpstreamObserver.containsDownstreamConnection = false
            }
            
            if coordinateValueChanged {
                // Flatten values
                let newFlattenedValues = self.allLoopedValues.flattenValues()
                self.updateValues(newFlattenedValues)
                
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
}
