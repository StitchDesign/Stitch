//
//  LayerNodeData.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/18/24.
//

import Foundation
import StitchSchemaKit

extension LayerInputObserver {
    
    // Called from various UI, e.g. `CommonEditingView`,
    // which could be for a field on the canvas or in the layer inspector
    @MainActor
    func fieldHasHeterogenousValues(_ fieldIndex: Int,
                                    isFieldInsideLayerInspector: Bool) -> Bool {

        let layerInputPort: LayerInputPort = self.port
        
        // Only relevant when this layer-input field is in the layer inspector and multiple layers are selected
        guard isFieldInsideLayerInspector,
              let graph = self.graphDelegate,
              graph.multiselectInputs.isDefined else {
            return false
        }
        
        return layerInputPort
            .fieldsInMultiselectInputWithHeterogenousValues(graph)
            .contains(fieldIndex)
    }
}

protocol LayerNodeRowData: AnyObject {
    associatedtype RowObserverable: NodeRowObserver
    
    var rowObserver: RowObserverable { get set }
    var canvasObserver: CanvasItemViewModel? { get set }
    var inspectorRowViewModel: RowObserverable.RowViewModelType { get set }
}

/*
 Data for a single "row"; could represent a packed input or a single field of an unpacked input.
 
 So e.g. could be for Size input, or Size input's Width or Height field.
 */
@Observable
final class InputLayerNodeRowData: LayerNodeRowData, Identifiable {
    let id: LayerInputType
    var rowObserver: InputNodeRowObserver
    var inspectorRowViewModel: InputNodeRowViewModel
    var canvasObserver: CanvasItemViewModel?
    
    // Better to keep it here, outside of the view?
    // - Consolidate in a single place
    
    // Called from various UI, e.g. `CommonEditingView`,
    // which could be for a field on the canvas or in the layer inspector
    @MainActor
    func fieldHasHeterogenousValues(_ fieldIndex: Int,
                                    isFieldInsideLayerInspector: Bool) -> Bool {

        // Only relevant when this layer-input field is in the layer inspector and multiple layers are selected
        guard isFieldInsideLayerInspector,
              let graphDelegate = self.inspectorRowViewModel.graphDelegate,
              graphDelegate.multiselectInputs.isDefined else {
            return false
        }
    
         return self.id.layerInput
            .fieldsInMultiselectInputWithHeterogenousValues(graphDelegate)
            .contains(fieldIndex)
    }
    
    init(rowObserver: InputNodeRowObserver,
         canvasObserver: CanvasItemViewModel? = nil,
         nodeDelegate: NodeDelegate? = nil) {
        let keyPath = rowObserver.id.keyPath
        assertInDebug(keyPath.isDefined)
        
        self.id = keyPath ?? .init(layerInput: .position, portType: .packed)
        self.rowObserver = rowObserver
        self.canvasObserver = canvasObserver
        var itemType: GraphItemType
        
        if let inputType = rowObserver.id.keyPath {
            itemType = .layerInspector(.keyPath(inputType))
        } else {
            fatalErrorIfDebug()
            itemType = .empty
        }
        
        // When we initialize this `inspectorRowViewModel` ... where do we create the field types then?
        self.inspectorRowViewModel = .init(id: .init(graphItemType: itemType,
                                                     nodeId: rowObserver.id.nodeId,
                                                     // Why portId=0 ?
                                                     portId: 0),
                                           rowDelegate: rowObserver,
                                           // specifically not a row view model for canvas
                                           canvasItemDelegate: nil)
    }
}

@Observable
final class OutputLayerNodeRowData: LayerNodeRowData {
    var rowObserver: OutputNodeRowObserver
    var inspectorRowViewModel: OutputNodeRowViewModel
    var canvasObserver: CanvasItemViewModel?
    
    init(rowObserver: OutputNodeRowObserver,
         canvasObserver: CanvasItemViewModel? = nil) {
        self.rowObserver = rowObserver
        self.canvasObserver = canvasObserver
        var itemType: GraphItemType
        
        if let portId = rowObserver.id.portId {
            itemType = .layerInspector(.portIndex(portId))
        } else {
            fatalErrorIfDebug()
            itemType = .empty
        }
        
        self.inspectorRowViewModel = .init(id: .init(graphItemType: itemType,
                                                     nodeId: rowObserver.id.nodeId,
                                                     portId: 0),
                                           rowDelegate: rowObserver,
                                           // specifically not a row view model for canvas
                                           canvasItemDelegate: nil)
    }
    
    @MainActor
    func initializeDelegate(_ node: NodeDelegate) {
        self.rowObserver.initializeDelegate(node)
        self.canvasObserver?.initializeDelegate(node,
                                                // Not relevant
                                                unpackedPortParentFieldGroupType: nil,
                                                unpackedPortIndex: nil)
        self.inspectorRowViewModel.initializeDelegate(node,
                                                      // Not relevant
                                                      unpackedPortParentFieldGroupType: nil,
                                                      unpackedPortIndex: nil)
    }
}

extension LayerNodeRowData {
    @MainActor
    func initializeDelegate(_ node: NodeDelegate,
                            unpackedPortParentFieldGroupType: FieldGroupType?,
                            unpackedPortIndex: Int?) {
        self.rowObserver.initializeDelegate(node)
        self.canvasObserver?.initializeDelegate(node,
                                                unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                unpackedPortIndex: unpackedPortIndex)
        self.inspectorRowViewModel.initializeDelegate(node,
                                                      unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                                      unpackedPortIndex: unpackedPortIndex)
    }
    
    var allLoopedValues: PortValues {
        get {
            self.rowObserver.allLoopedValues
        }
        set(newValue) {
            self.rowObserver.allLoopedValues = newValue
        }
    }
}

extension LayerNodeViewModel {
    /// First step for layer port initialization before schema settings are set.
    func preinitializeSupportedPort(layerInputPort: LayerInputPort,
                                    portType: LayerInputKeyPathType) {
        let layerId = LayerInputType(layerInput: layerInputPort,
                                     portType: portType)
        let coordinateId = NodeIOCoordinate(portType: .keyPath(layerId), nodeId: self.id)
        
        let layerData: InputLayerNodeRowData = self[keyPath: layerId.layerNodeKeyPath]
        
        // Update row view model ID
        layerData.inspectorRowViewModel.id = .init(graphItemType: .layerInspector(.keyPath(layerId)),
                                                   nodeId: self.id,
                                                   portId: 0)
        
        // Update packed row observer
        layerData.rowObserver.nodeKind = .layer(self.layer)
        layerData.rowObserver.id = coordinateId
    }
    
    /// Second step for layer port initialization after all initial identifier data is set.
    @MainActor
    func initializePortSchema(layerSchema: LayerNodeEntity,
                              layerInputPort: LayerInputPort) {
        let layerData = self[keyPath: layerInputPort.layerNodeKeyPath]
        
        layerData.update(from: layerSchema[keyPath: layerInputPort.schemaPortKeyPath],
                         layerInputType: layerInputPort,
                         layerNode: self,
                         nodeId: self.id)
    }
}

extension InputLayerNodeRowData {
    func update(from schema: LayerInputDataEntity,
                layerInputType: LayerInputType,
                layerNode: LayerNodeViewModel,
                nodeId: NodeId,
                unpackedPortParentFieldGroupType: FieldGroupType?,
                unpackedPortIndex: Int?) {
        self.rowObserver.id.nodeId = nodeId
                    
        if let canvas = schema.canvasItem {
            if let canvasObserver = self.canvasObserver {
                canvasObserver.update(from: canvas)
                
            } else {
                // Make new canvas observer since none yet created
                let canvasId = CanvasItemId.layerInput(.init(node: nodeId,
                                                             keyPath: layerInputType))
                
                self.canvasObserver = .init(from: canvas,
                                            id: canvasId,
                                            inputRowObservers: [self.rowObserver],
                                            outputRowObservers: [],
                                            unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                            unpackedPortIndex: unpackedPortIndex)

                // NOTE: DO NOT SET A CANVAS ITEM DELEGATE ON AN INSPECTOR ROW VIEW MODEL
//                self.inspectorRowViewModel.canvasItemDelegate = self.canvasObserver
            }
        } else {
            self.canvasObserver = nil
        }
    }
}

extension LayerInputObserver {
    var packedObserver: InputLayerNodeRowData? {
        switch self.mode {
        case .packed:
            return self.packedObserver
        case .unpacked:
            return nil
        }
    }
    
    var unpackedObserver: LayerInputUnpackedPortObserver? {
        switch self.mode {
        case .unpacked:
            return self._unpackedData
        default:
            return nil
        }
    }
    
    @MainActor
    func update(from schema: LayerInputEntity,
                layerInputType: LayerInputPort,
                layerNode: LayerNodeViewModel,
                nodeId: NodeId) {        
        let portObserver = layerNode[keyPath: layerInputType.layerNodeKeyPath]
        let unpackedObservers = portObserver._unpackedData.allPorts

        self.port = layerInputType
        
        // Updated packed data
        portObserver._packedData.update(from: schema.packedData,
                                        layerInputType: .init(layerInput: layerInputType,
                                                              portType: .packed),
                                        layerNode: layerNode,
                                        nodeId: nodeId,
                                        // Not relevant
                                        unpackedPortParentFieldGroupType: nil,
                                        unpackedPortIndex: nil)
        
        
        // Update unpacked data
        zip(unpackedObservers, schema.unpackedData).enumerated().forEach { portId, data in
            guard let unpackedPortType = UnpackedPortType(rawValue: portId) else {
                fatalErrorIfDebug()
                return
            }
            
            let unpackedObserver = data.0
            let unpackedSchema = data.1
                        
            let unpackedPortParentFieldGroupType: FieldGroupType = layerInputType
                .getDefaultValue(for: layerNode.layer)
                .getNodeRowType(nodeIO: .input)
                .getFieldGroupTypeForLayerInput
            
            unpackedObserver.update(from: unpackedSchema,
                                    layerInputType: .init(layerInput: layerInputType,
                                                          portType: .unpacked(unpackedPortType)),
                                    layerNode: layerNode,
                                    nodeId: nodeId,
                                    unpackedPortParentFieldGroupType: unpackedPortParentFieldGroupType,
                                    unpackedPortIndex: portId)
        }
        
        // Update values once mode is known (requires updating canvas items first)
        // This logic is needed to prevent a bug where unpacked mode updates packed observer values despite upstream connection
        switch self.observerMode {
        case .packed(let packedObserver):
            packedObserver.rowObserver.update(from: schema.packedData.inputPort,
                                              inputType: .init(layerInput: layerInputType,
                                                               portType: .packed))
            
        case .unpacked:
            zip(unpackedObservers, schema.unpackedData).enumerated().forEach { portId, data in
                guard let unpackedPortType = UnpackedPortType(rawValue: portId) else {
                    fatalErrorIfDebug()
                    return
                }
                
                let unpackedObserver = data.0
                let unpackedSchema = data.1
                
                unpackedObserver.rowObserver.update(from: unpackedSchema.inputPort,
                                                    inputType: .init(layerInput: layerInputType,
                                                                     portType: .unpacked(unpackedPortType)))
            }
        }
    }
    
    @MainActor
    func createSchema() -> LayerInputEntity {
        .init(packedData: self._packedData.createSchema(),
              unpackedData: self._unpackedData.allPorts.map { $0.createSchema() })
    }
}
    
extension InputLayerNodeRowData {
    @MainActor
    func createSchema() -> LayerInputDataEntity {
        .init(inputPort: self.rowObserver.createSchema().portData,
              canvasItem: self.canvasObserver?.createSchema())
    }
}

extension OutputLayerNodeRowData: Identifiable {
    var id: NodeIOCoordinate {
        self.rowObserver.id
    }
}
