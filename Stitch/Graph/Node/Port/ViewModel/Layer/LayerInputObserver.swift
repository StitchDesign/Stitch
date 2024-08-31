//
//  LayerInputObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/14/24.
//

import Foundation
import StitchSchemaKit

// Must be a class for coordinate keypaths, which expect a reference type on the other end.
@Observable
final class LayerInputObserver {
    // Not intended to be used as an API given both data payloads always exist
    // Variables here necessary to ensure keypaths logic works
    var _packedData: InputLayerNodeRowData
    var _unpackedData: LayerInputUnpackedPortObserver
    
    let layer: Layer
    var port: LayerInputPort
    
    @MainActor
    init(from schema: LayerNodeEntity, port: LayerInputPort) {
        self.layer = schema.layer
        self.port = port
        
        self._packedData = .empty(.init(layerInput: port,
                                        portType: .packed),
                                  layer: schema.layer)
        
        self._unpackedData = .init(layerPort: port,
                                   layer: schema.layer,
                                   port0: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port0)),
                                                 layer: schema.layer),
                                   port1: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port1)),
                                                 layer: schema.layer),
                                   port2: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port2)),
                                                 layer: schema.layer),
                                   port3: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port3)),
                                                 layer: schema.layer))
    }
}

extension LayerInputObserver {
    @MainActor
    var mode: LayerInputMode {
        if self._unpackedData.allPorts.contains(where: { $0.canvasObserver.isDefined }) {
            return .unpacked
        }
        
        return .packed
    }
    
    /// Updates all-up values, handling scenarios like unpacked if applicable.
    @MainActor func updatePortValues(_ values: PortValues) {
        // Updating the packed observer will always update unpacked observers if the mode is set as unpacked
        self._packedData.rowObserver.updateValues(values)
    }
    
    /// All-up values for this port
    @MainActor
    var allLoopedValues: PortValues {
        switch self.observerMode {
        case .packed(let packedObserver):
            return packedObserver.allLoopedValues

        case .unpacked(let unpackedObserver):
            let valuesFromUnpackedObservers = unpackedObserver.getParentPortValuesList()
            return valuesFromUnpackedObservers
        }
    }
    
    @MainActor
    var observerMode: LayerInputObserverMode {
        switch self.mode {
        case .packed:
            return .packed(self._packedData)
        case .unpacked:
            return .unpacked(self._unpackedData)
        }
    }
    
    @MainActor
    var values: PortValues {
        switch self.mode {
        case .packed:
            return self._packedData.rowObserver.values
        case .unpacked:
            return self._unpackedData.getParentPortValuesList()
        }
    }
    
    @MainActor
    var graphDelegate: GraphDelegate? {
        // Hacky solution, just get row observer delegate from packed data
        self._packedData.rowObserver.nodeDelegate?.graphDelegate
    }
    
    @MainActor var activeValue: PortValue {
        let activeIndex = self.graphDelegate?.activeIndex ?? .init(.zero)
        let values = self.values
        
        guard let value = values[safe: activeIndex.adjustedIndex(values.count)] else {
            fatalErrorIfDebug()
            return values.first ?? .none
        }
        
        return value
    }
    
    @MainActor
    var allInputData: [InputLayerNodeRowData] {
        switch self.observerMode {
        case .packed(let packedData):
            return [packedData]
        case .unpacked(let unpackedObserver):
            return unpackedObserver.allPorts
        }
    }
    
    @MainActor func initializeDelegate(_ node: NodeDelegate) {
        self._packedData.initializeDelegate(node)
        self._unpackedData.initializeDelegate(node)
    }
    
    @MainActor func getAllCanvasObservers() -> [CanvasItemViewModel] {
        switch self.observerMode {
        case .packed(let packedData):
            if let canvas = packedData.canvasObserver {
                return [canvas]
            }
            return []
        case .unpacked(let unpackedData):
            return unpackedData.allPorts.compactMap {
                $0.canvasObserver
            }
        }
    }
    
    /// Called after the pack mode changes for some port.
    @MainActor func wasPackModeToggled() {
        let nodeId = self._packedData.rowObserver.id.nodeId
        
        guard let node = self.graphDelegate?.getNodeViewModel(nodeId),
              let layerNode = node.layerNode else {
            fatalErrorIfDebug()
            return
        }
        
        switch self.mode {
        case .unpacked:
            // Get values from previous packed mode
            let values = self._packedData.allLoopedValues
            
            // Reset packed state
            self._packedData.resetOnPackModeToggle()
            
            // Update values of new unpacked row observers
            self._unpackedData.updateValues(from: values,
                                            layerNode: layerNode)
            
        case .packed:
            // Get values from previous unpacked mode
            let values = self._unpackedData.getParentPortValuesList()
            
            // Reset unpacked state
            self._unpackedData.allPorts.forEach {
                $0.resetOnPackModeToggle()
            }
            
            // Update values to packed observer
            self._packedData.rowObserver.updateValues(values)
        }
        
        self.graphDelegate?.updateGraphData(document: nil)
    }
    
    /// Helper only intended for use with ports that don't support unpacked mode.
    @MainActor
    var rowObserver: InputNodeRowObserver {
        assertInDebug(self.mode == .packed)
        return self._packedData.rowObserver
    }
}

extension InputLayerNodeRowData {
    /// Resets canvas data and connections when toggled between pack/unpack state.
    func resetOnPackModeToggle() {
        self.rowObserver.upstreamOutputCoordinate = nil
        self.canvasObserver = nil
    }
}

enum LayerInputMode {
    case packed
    case unpacked
}

enum LayerInputObserverMode {
    case packed(InputLayerNodeRowData)
    case unpacked(LayerInputUnpackedPortObserver)
}
