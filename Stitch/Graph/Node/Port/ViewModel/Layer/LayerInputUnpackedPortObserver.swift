//
//  LayerInputUnpackedPortObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/14/24.
//

import Foundation
import StitchSchemaKit

final class LayerInputUnpackedPortObserver {
    let layerPort: LayerInputPort
    let layer: Layer
    
    var port0: InputLayerNodeRowData
    var port1: InputLayerNodeRowData
    var port2: InputLayerNodeRowData
    var port3: InputLayerNodeRowData
    
    init(layerPort: LayerInputPort,
         layer: Layer,
         port0: InputLayerNodeRowData,
         port1: InputLayerNodeRowData,
         port2: InputLayerNodeRowData,
         port3: InputLayerNodeRowData) {
        self.layerPort = layerPort
        self.layer = layer
        self.port0 = port0
        self.port1 = port1
        self.port2 = port2
        self.port3 = port3
    }
    
    /// Only to be used by `allPorts` helper.
    private var _allAvailablePorts: [InputLayerNodeRowData] {
        [port0, port1, port2, port3]
    }
}

extension LayerInputUnpackedPortObserver {
    @MainActor
    func getParentPortValuesList() -> PortValues {
        let allRawValues: PortValuesList = allPorts.map { $0.allLoopedValues }
        let lengthenedValues: PortValuesList = allRawValues.lengthenArrays()
        
        // Remap values so we can process packing logic
        let remappedValues = lengthenedValues.remapValuesByLoop()
        let packedValues = remappedValues.map { valuesList in
            self.layerPort.packValues(from: valuesList,
                                      layer: self.layer)
        }
        
        return packedValues
    }
    
    @MainActor
    var allPorts: [InputLayerNodeRowData] {
        guard let portsToUse = layerPort.unpackedPortCount(layer: self.layer) else {
            return []
        }
        
        let relevantPorts = self._allAvailablePorts.prefix(upTo: portsToUse)
        assertInDebug(portsToUse == relevantPorts.count)
        
        return Array(relevantPorts)
    }
    
    @MainActor
    func createSchema() -> [LayerInputDataEntity] {
        self.allPorts.map { $0.createSchema() }
    }
    
    @MainActor
    /// From packed values, unpacks them for unpack layer input scenario.
    func updateValues(from packedValues: PortValues,
                      layerNode: LayerNodeViewModel) {
        let unpackedValues = packedValues.map { self.layerPort.unpackValues(from: $0) }
        
        guard let unpackedPortCount = unpackedValues.first??.count else {
            fatalErrorIfDebug()
            return
        }
        
        // Remap values to be all organized for a particular port
        (0..<unpackedPortCount).forEach { portId in
            guard let unpackedId = UnpackedPortType(rawValue: portId) else {
                fatalErrorIfDebug()
                return
            }
            
            // Grab loop of values from unpacked array for this indexed unpacked port
            let values = unpackedValues.map {
                guard let value = $0?[safe: portId] else {
                    fatalErrorIfDebug()
                    return PortValue.none
                }
                
                return value
            }
            
            let portTypeId: LayerInputKeyPathType = .unpacked(unpackedId)
            let layerId = LayerInputType(layerInput: self.layerPort,
                                        portType: portTypeId)
            let rowObserver = layerNode[keyPath: layerId.layerNodeKeyPath].rowObserver
            
            // Update row observer values per usual
            rowObserver.updateValues(values)
        }
    }
}
