//
//  LayerInputUnpackedPortObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/14/24.
//

import Foundation
import StitchSchemaKit

/// Visually organizes unpacked ports into groups to mimic grouping behavior in packed inputs.
/// Grouped inputs currently only used for transform 3D.
struct GroupedLayerInputData {
    let label: String
    let portRange: Range<Int>
}

final class LayerInputUnpackedPortObserver {
    let layerPort: LayerInputPort
    let layer: Layer
    
    var port0: InputLayerNodeRowData
    var port1: InputLayerNodeRowData
    var port2: InputLayerNodeRowData
    var port3: InputLayerNodeRowData
    var port4: InputLayerNodeRowData
    var port5: InputLayerNodeRowData
    var port6: InputLayerNodeRowData
    var port7: InputLayerNodeRowData
    var port8: InputLayerNodeRowData
    
    init(layerPort: LayerInputPort,
         layer: Layer,
         port0: InputLayerNodeRowData,
         port1: InputLayerNodeRowData,
         port2: InputLayerNodeRowData,
         port3: InputLayerNodeRowData,
         port4: InputLayerNodeRowData,
         port5: InputLayerNodeRowData,
         port6: InputLayerNodeRowData,
         port7: InputLayerNodeRowData,
         port8: InputLayerNodeRowData) {
        
        self.layerPort = layerPort
        self.layer = layer
        self.port0 = port0
        self.port1 = port1
        self.port2 = port2
        self.port3 = port3
        self.port4 = port4
        self.port5 = port5
        self.port6 = port6
        self.port7 = port7
        self.port8 = port8
    }
    
    /// Only to be used by `allPorts` helper.
    private var _allAvailablePorts: [InputLayerNodeRowData] {
        [port0, port1, port2, port3, port4, port5, port6, port7, port8]
    }
}

extension LayerInputUnpackedPortObserver {
    // NOT USED?
    var groupings: [GroupedLayerInputData]? {
        self.layerPort.transform3DLabelGroupings
    }
    
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
    
    var allPorts: [InputLayerNodeRowData] {
        guard let portsToUse = layerPort.unpackedPortCount(layer: self.layer) else {
            return []
        }
        
        let relevantPorts = self._allAvailablePorts.prefix(upTo: portsToUse)
        assertInDebug(portsToUse == relevantPorts.count)
        
        return Array(relevantPorts)
    }
    
//    @MainActor
//    func createSchema() -> [LayerInputDataEntity] {
//        self.allPorts.map { $0.createSchema() }
//    }
    
    // fka `updateValues` but changed becuse XCode was incorrectly picking it up as a use of a `NodeRowObserver.updateValues`
    /// From packed values, unpacks them for unpack layer input scenario.
    @MainActor
    func updateUnpackedObserverValues(from packedValues: PortValues,
                                      layerNode: LayerNodeViewModel) {
        let unpackedValues = packedValues.map { $0.unpackValues() }
        
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
            rowObserver.updateValuesInInput(values)
        }
    }
}
