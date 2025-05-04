//
//  LayerInputObserver.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 8/14/24.
//

import Foundation
import StitchSchemaKit

extension LayerNodeViewModel {
    @MainActor
    func getLayerInputObserver(_ layerInput: LayerInputPort) -> LayerInputObserver {
        self[keyPath: layerInput.layerNodeKeyPath]
    }
}

extension LayerInputPort {
    
    var asFullInput: LayerInputType {
        .init(layerInput: self,
              portType: .packed)
    }
    
    var asFirstField: LayerInputType {
        .init(layerInput: self,
              portType: .unpacked(.port0))
    }
    
    // Note: we currently don't block any fields in inputs with 3 or more fields
    var asSecondField: LayerInputType {
        .init(layerInput: self,
              portType: .unpacked(.port1))
    }
}

// TODO: use Set<BlockedFieldIndex> instead of Set<LayerInputKeyPathType>, to avoid complications of LayerInputType etc.; full input blocked = Set([.first, .second])
enum BlockedFieldIndex: Codable, Equatable, Hashable {
    case first, second
}

// Must be a class for coordinate keypaths, which expect a reference type on the other end.
@Observable
final class LayerInputObserver: Identifiable {
    // Not intended to be used as an API given both data payloads always exist
    // Variables here necessary to ensure keypaths logic works

    let nodeId: NodeId
    
    let layer: Layer
    
    // TODO: use `private` to prevent access?
    var _packedData: InputLayerNodeRowData
    var _unpackedData: LayerInputUnpackedPortObserver
    
    @MainActor let port: LayerInputPort

    /*
     Only fields on a layer input (not a patch input or layer output) can be blocked,
     and a field is blocked regardless of pack vs unpack mode.
     
     Example use with LayerInputObserver for the .minSize input:
     
     // the entire minSize input blocked:
     self.blockedFields.contains(.packed)
     
     // just the width field on the minSize input blocked:
     self.blockedFields.contains(.unpacked(.port0))
     */
    @MainActor var blockedFields: Set<LayerInputKeyPathType>
    
    @MainActor
    init(from schema: LayerNodeEntity,
         port: LayerInputPort) {
        let nodeId = schema.id
        self.nodeId = nodeId
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

extension Int {
    var asUnpackedPortType: UnpackedPortType {
        switch self {
        case 0:
            return .port0
        case 1:
            return .port1
        case 2:
            return .port2
        case 3:
            return .port3
        case 4:
            return .port4
        case 5:
            return .port5
        case 6:
            return .port6
        case 7:
            return .port7
        case 8:
            return .port8
        default:
            fatalErrorIfDebug()
            return .port0
        }
    }
}

extension LayerInputObserver {
    // Used with a specific flyout-row, to add the field of the canvas
    @MainActor
    func layerInputTypeForFieldIndex(_ fieldIndex: Int) -> LayerInputType {
        .init(layerInput: self.port,
                     portType: .unpacked(fieldIndex.asUnpackedPortType))
    }
}


extension LayerInputObserver {
    
    // "Does this layer input use multifield fields?"
    // Regardless of packed vs unpacked mode.
    @MainActor
    var usesMultifields: Bool {
        switch self.mode {
        case .packed:
            return (self.fieldGroupsFromInspectorRowViewModels.first?.fieldObservers.count ?? 0) > 1
        case .unpacked:
            return self.fieldGroupsFromInspectorRowViewModels.count > 1
        }
    }
    
    // Currently, spacing
    @MainActor
    func usesGridMultifieldArrangement() -> Bool {
        self.port.getDefaultValue(for: self.layer).getPadding.isDefined
    }
    
    // The overall-label for the port, e.g. "Size" (not "W" or "H") for the size property
    @MainActor
    func overallPortLabel(usesShortLabel: Bool) -> String {
        self.port.label(useShortLabel: usesShortLabel)
    }
    
    @MainActor
    func areAllFieldsBlocked() -> Bool {
        self.fieldGroupsFromInspectorRowViewModels.allSatisfy { (fieldGroup: FieldGroup) in
            fieldGroup.areAllFieldsBlocked(blockedFields: self.blockedFields)
        }
    }
    
    // Returns all field groups, regardless of packed vs unpacked; draws them from the inspector row view models (guaranteed to be present)
    // TODO: are a layer input's canvas and inspector row view models always updated in sync?
    @MainActor
    var fieldGroupsFromInspectorRowViewModels: [FieldGroup] {
        let allFields = self.allInputData.flatMap { (portData: InputLayerNodeRowData) in
            portData.inspectorRowViewModel.cachedFieldGroups
        }
        
        switch self.mode {
        case .packed:
            return allFields
            
        case .unpacked:
            // Vast majority of unpacked cases simply directly return inspector row view models
            // Note:
            guard let groupings = self.port.transform3DLabelGroupings else {
                return allFields
            }
            
            // Groupings are gone in unpacked mode so we just need the fields
            let flattenedFields = allFields.flatMap { $0.fieldObservers }
            
            let fieldGroupsFromPacked = self._packedData.inspectorRowViewModel.cachedFieldGroups
            
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
        // Only intended for packed layer input
        if self.mode == .unpacked {
            return nil
        } else {
            return self.getAllCanvasObservers().first
        }
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
        self.packedRowObserver.updateValuesInInput(values)
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
        switch self.observerMode {
        case .packed(let packed):
            return packed.allLoopedValues
        case .unpacked:
            return self._unpackedData.getParentPortValuesList()
        }
    }
    
    @MainActor
    func getActiveValue(activeIndex: ActiveIndex) -> PortValue {
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
    func initializeDelegate(_ node: NodeViewModel,
                            layer: Layer,
                            activeIndex: ActiveIndex,
                            graph: GraphState) {
                
        self._packedData.initializeDelegate(node,
                                            // Not relevant for packed data
                                            unpackedPortParentFieldGroupType: nil,
                                            unpackedPortIndex: nil,
                                            activeIndex: activeIndex,
                                            graph: graph)
                
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
                                    unpackedPortIndex: fieldIndex,
                                    activeIndex: activeIndex,
                                    graph: graph)
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
    func wasPackModeToggled(document: StitchDocumentViewModel) {
                
        let graph = document.visibleGraph
        
        guard let node = graph.getNode(self.nodeId),
              let layerNode = node.layerNode else {
            fatalErrorIfDebug()
            return
        }
        
        // The mode we toggled to
        let newMode = self.mode
        
        switch newMode {
        
        case .unpacked:
            // Get values from previous packed mode
            let values = self.packedRowObserver.allLoopedValues
            
            // Note: why do we do this?
            
            // Reset packed state
            self._packedData.resetOnPackModeToggle()
            
            // Update values of new unpacked row observers
            self._unpackedData.updateUnpackedObserverValues(from: values,
                                                            layerNode: layerNode)
            
        case .packed:
            // Get values from previous unpacked mode
            let values: PortValues = self._unpackedData.getParentPortValuesList()
            
            // Reset unpacked state
            self._unpackedData.allPorts.forEach {
                $0.resetOnPackModeToggle()
            }
            
            // Update values to packed observer
            self.packedRowObserver.setValuesInInput(values)
        }
        
        // TODO: why do we need to do this? Is it updating the UI?
        graph.updateGraphData(document)
    }
    
    /// Helper only intended for use with ports that don't support unpacked mode.
    @MainActor
    var packedRowObserver: InputNodeRowObserver {
        self._packedData.rowObserver
    }
    
    @MainActor
    var packedRowObserverOnlyIfPacked: InputNodeRowObserver? {
        self.mode == .packed ? self._packedData.rowObserver : nil
    }
    
    @MainActor
    var packedCanvasObserverOnlyIfPacked: CanvasItemViewModel? {
        self.mode == .packed ? self._packedData.canvasObserver : nil
    }
    
    // All row observers for this input; for working with row observer(s) regardless of pack vs unpack
    @MainActor
    var allRowObservers: [InputNodeRowObserver] {
        switch self.mode {
        case .packed:
            return [self.packedRowObserver]
        case .unpacked:
            return self._unpackedData.allPorts.map(\.rowObserver)
        }
    }
            
    @MainActor
    func useIndividualFieldLabel(activeIndex: ActiveIndex) -> Bool {
        // Do not use labels on the fields of a padding-type input
        !self.getActiveValue(activeIndex: activeIndex).getPadding.isDefined
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
