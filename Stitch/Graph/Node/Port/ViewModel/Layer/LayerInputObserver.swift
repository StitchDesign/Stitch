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

    let layer: Layer
    
    // TODO: use `private` to prevent access?
    var _packedData: InputLayerNodeRowData
    var _unpackedData: LayerInputUnpackedPortObserver
    
    @MainActor var port: LayerInputPort

    /*
     Only fields on a layer input (not a patch input or layer output) can be blocked,
     and a field is blocked regardless of pack vs unpack mode.
     
     Example use with LayerInputObserver for the .minSize input:
     
     // the entire minSize input blocked:
     self.blockedFields.contains(.packed)
     
     // just the width field on the minSize input blocked:
     self.blockedFields.contains(.unpacked(.port0))
     */
    @MainActor var blockedFields: Set<LayerInputKeyPathType> // = .init()
    
    @MainActor
    init(from schema: LayerNodeEntity,
         port: LayerInputPort) {
        let nodeId = schema.id
        self.layer = schema.layer
        self.port = port
                    
        self._packedData = .empty(.init(layerInput: port,
                                        portType: .packed),
                                  nodeId: nodeId,
                                  layer: schema.layer)
        
        // initial these with field indices that reflect port0 vs port1 vs port2 ..
        self._unpackedData = .init(layerPort: port,
                                   layer: schema.layer,
                                   port0: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port0)),
                                                 nodeId: nodeId,
                                                 layer: schema.layer),
                                   port1: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port1)),
                                                 nodeId: nodeId,
                                                 layer: schema.layer),
                                   port2: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port2)),
                                                 nodeId: nodeId,
                                                 layer: schema.layer),
                                   port3: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port3)),
                                                 nodeId: nodeId,
                                                 layer: schema.layer),
                                   port4: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port4)),
                                                 nodeId: nodeId,
                                                 layer: schema.layer),
                                   port5: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port5)),
                                                 nodeId: nodeId,
                                                 layer: schema.layer),
                                   port6: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port6)),
                                                 nodeId: nodeId,
                                                 layer: schema.layer),
                                   port7: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port7)),
                                                 nodeId: nodeId,
                                                 layer: schema.layer),
                                   port8: .empty(.init(layerInput: port,
                                                       portType: .unpacked(.port8)),
                                                 nodeId: nodeId,
                                                 layer: schema.layer))
        
        // When initialized fom schema, blockedFields is empty.
        // `blockedFields` is populated when we e.g. update `activeValue`
        self.blockedFields = .init()
    }
}

extension LayerInputType {
    var getUnpackedPortType: UnpackedPortType? {
        switch self.portType {
        case .unpacked(let unpackedPortType):
            return unpackedPortType
        default:
            return nil
        }
    }
}

extension LayerInputObserver {
    
    // "Does this layer input use multifield fields?"
    // Regardless of packed vs unpacked mode.
    @MainActor
    var usesMultifields: Bool {
        //        log("LayerInputObserver: usesMultifields: for layer input \(self.port)")
        switch self.mode {
        case .packed:
            return (self.fieldValueTypes.first?.fieldObservers.count ?? 0) > 1
        case .unpacked:
            return self.fieldValueTypes.count > 1
        }
    }
    
    // The overall-label for the port, e.g. "Size" (not "W" or "H") for the size property
    @MainActor
    func overallPortLabel(usesShortLabel: Bool,
                          node: NodeViewModel,
                          graph: GraphState) -> String {
        guard let label = self._packedData.inspectorRowViewModel.rowDelegate?
            .label(useShortLabel: true,
                   node: node,
                   graph: graph) else {
            fatalErrorIfDebug("Did not have rowDelegate?")
            return "NO LABEL"
        }
        return label
    }
        
    @MainActor
    var fieldValueTypes: [FieldGroupTypeData<InputNodeRowViewModel.FieldType>] {
        let allFields = self.allInputData.flatMap { (portData: InputLayerNodeRowData) in
            portData.inspectorRowViewModel.fieldValueTypes
        }
        
        switch self.mode {
        case .packed:
            return allFields
        case .unpacked:
            guard let groupings = self.port.labelGroupings else {
                return allFields
            }
            
            // Groupings are gone in unpacked mode so we just need the fields
            let flattenedFields = allFields.flatMap { $0.fieldObservers }
            let fieldGroupsFromPacked = self._packedData.inspectorRowViewModel.fieldValueTypes
            
            // Create nested array for label groupings (used for 3D model)
            return groupings.enumerated().map { fieldGroupIndex, labelData in
                var fieldGroupFromPacked = fieldGroupsFromPacked[fieldGroupIndex]
                let fieldsFromUnpacked = Array(flattenedFields[labelData.portRange])
                
                fieldGroupFromPacked.fieldObservers = fieldsFromUnpacked
                return fieldGroupFromPacked
            }
        }
    }
    
    @MainActor
    func getCanvasItemForWholeInput() -> CanvasItemViewModel? {
        let canvasObsevers = self.getAllCanvasObservers()
        if canvasObsevers.count > 1 {
            fatalErrorIfDebug()
            return nil
        }
        return canvasObsevers.first
    }
    
    @MainActor
    func getCanvasItem(for fieldIndex: Int) -> CanvasItemViewModel? {
        // Important: if fieldIndex = 0, but there's only e.g. one canvas item (which is for port1), then we'll incorrectly return port1's canvas item
//        self.getAllCanvasObservers()[safeIndex: fieldIndex]
        
        self.getAllCanvasObservers().first { (canvas: CanvasItemViewModel) in
            canvas.id.layerInputCase?.keyPath.getUnpackedPortType?.rawValue == fieldIndex
        }
    }
    
    @MainActor
    var mode: LayerInputMode {
        if self._unpackedData.allPorts.contains(where: { $0.canvasObserver.isDefined }) {
            return .unpacked
        }
        
        return .packed
    }
    
    // TODO: why is this _packed only ?
    /// Updates all-up values, handling scenarios like unpacked if applicable.
    @MainActor
    func updatePortValues(_ values: PortValues) {
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
    func layerInputType(fieldIndex: Int) -> LayerInputType {
        switch self.mode {
        case .packed:
            return .init(layerInput: self.port,
                         portType: .packed)
        case .unpacked:
            return .init(layerInput: self.port,
                         portType: .unpacked(fieldIndex.asUnpackedPortType))
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
    
    @MainActor
    var activeValue: PortValue {
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
     
    @MainActor
    func initializeDelegate(_ node: NodeDelegate,
                            layer: Layer) {
                
        self._packedData.initializeDelegate(node,
                                            // Not relevant for packed data
                                            unpackedPortParentFieldGroupType: nil,
                                            unpackedPortIndex: nil)
                
        let layerInput: LayerInputPort = self.port
                
        // MARK: first group type grabbed since layers don't have differing groups within one input
        let unpackedPortParentFieldGroupType = layerInput
            .getDefaultValue(for: layer)
            .getNodeRowType(nodeIO: .input,
                            layerInputPort: layerInput,
                            isLayerInspector: true)
            .fieldGroupTypes
            .first
        
        self._unpackedData.allPorts.enumerated().forEach { fieldIndex, port in
            port.initializeDelegate(node,
                                    unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                    unpackedPortIndex: fieldIndex)
        }
    }
    
    @MainActor 
    func getAllCanvasObservers() -> [CanvasItemViewModel] {
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
    @MainActor 
    func wasPackModeToggled() {
        
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
            
            // Note: why do we do this?
            
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
        
        self.graphDelegate?.updateGraphData()
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
    @MainActor
    func resetOnPackModeToggle() {
        self.rowObserver.upstreamOutputCoordinate = nil
        self.canvasObserver = nil
    }
}

enum LayerInputMode: Equatable, Hashable {
    case packed
    case unpacked
}

enum LayerInputObserverMode {
    case packed(InputLayerNodeRowData)
    case unpacked(LayerInputUnpackedPortObserver)
}

extension LayerInputObserverMode {

    var isPacked: Bool {
        switch self {
        case .packed:
            return true
        case .unpacked:
            return false
        }
    }
    
    var isUnpacked: Bool {
        switch self {
        case .packed:
            return false
        case .unpacked:
            return true
        }
    }
}
