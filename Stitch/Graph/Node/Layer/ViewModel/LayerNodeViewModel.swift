//
//  LayerNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/28/21.
//

import CoreData
import Foundation
import SwiftUI
import StitchSchemaKit
import StitchEngine

typealias LayerNode = NodeViewModel
typealias LayerNodes = [LayerNode]

final class LayerInputUnpackedPortObserver {
    let layerPort: LayerInputPort
    let layer: Layer
    
    var port0: InputLayerNodeRowData
    var port1: InputLayerNodeRowData
    var port2: InputLayerNodeRowData
    
    init(layerPort: LayerInputPort,
         layer: Layer,
         port0: InputLayerNodeRowData,
         port1: InputLayerNodeRowData,
         port2: InputLayerNodeRowData) {
        self.layerPort = layerPort
        self.layer = layer
        self.port0 = port0
        self.port1 = port1
        self.port2 = port2
    }
    
    /// Only to be used by `allPorts` helper.
    private var _allAvailablePorts: [InputLayerNodeRowData] {
        [port0, port1, port2]
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
            fatalErrorIfDebug("API used for port which doesn't support unpacking")
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
    func initializeDelegate(_ node: NodeDelegate) {
        self.allPorts.forEach {
            $0.initializeDelegate(node)
        }
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

///// Needs to be class for StitchEngine which assumes reference objects with its mutation logic
//final class LayerInputObserver {
//    var id: NodeIOCoordinate    // ID used for NodeRowCalculatable
//    var type: LayerInputMode
//    
//    init(id: NodeIOCoordinate,
//         type: LayerInputObserverMode) {
//        self.id = id
//        self.type = type
//    }
//}

// Must be a class for coordinate keypaths, which expect a reference type on the other end.
@Observable
final class LayerInputObserver {
    // Not intended to be used as an API given both data payloads always exist
    // Variables here necessary to ensure keypaths logic works
    var _packedData: InputLayerNodeRowData
    var _unpackedData: LayerInputUnpackedPortObserver
    
    let layer: Layer
    let port: LayerInputPort
    var mode: LayerInputMode = .packed
    
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
                                                 layer: schema.layer))
    }
}

enum LayerInputObserverMode {
    case packed(InputLayerNodeRowData)
    case unpacked(LayerInputUnpackedPortObserver)
}

extension LayerInputObserver {
    /// Updates all-up values, handling scenarios like unpacked if applicable.
    @MainActor func updatePortValues(_ values: PortValues) {
        // Updating the packed observer will always update unpacked observers if the mode is set as unpacked
        self._packedData.rowObserver.updateValues(values)
    }
    
    /// All-up values for this port
    var allLoopedValues: PortValues {
        self._packedData.allLoopedValues
    }
    
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
        switch self.mode {
        case .packed:
            self._packedData.initializeDelegate(node)
        case .unpacked:
            self._unpackedData.initializeDelegate(node)
        }
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
    
    @MainActor func toggleMode() {
        let nodeId = self._packedData.rowObserver.id.nodeId
        let parentGroupNodeId = self.graphDelegate?.groupNodeFocused
        
        guard let node = self.graphDelegate?.getNodeViewModel(nodeId),
              let layerNode = node.layerNode else {
            fatalErrorIfDebug()
            return
        }
        
        switch self.mode {
        case .packed:
            // Reset packed state
            self._packedData.resetOnPackModeToggle()
            
            // Toggle state
            self.mode = .unpacked
            self._unpackedData.allPorts.forEach { unpackedPort in
                var unpackSchema = unpackedPort.createSchema()
                unpackSchema.canvasItem = .init(position: .zero,
                                                zIndex: .zero,
                                                parentGroupNodeId: parentGroupNodeId)
                unpackedPort.update(from: unpackSchema,
                                    layerInputType: unpackedPort.id,
                                    layerNode: layerNode,
                                    nodeId: nodeId,
                                    nodeDelegate: node)
            }
            
        case .unpacked:
            guard let packedKeyPath = self.__packedData.rowObserver.id.keyPath else {
                fatalErrorIfDebug()
                return
            }

            // Reset unpacked state
            self._unpackedData.allPorts.forEach {
                $0.resetOnPackModeToggle()
            }
            
            // Toggle state
            self.mode = .packed
            
            var packedSchema = self._packedData.createSchema()
            packedSchema.canvasItem = .init(position: .zero,
                                            zIndex: .zero,
                                            parentGroupNodeId: parentGroupNodeId)
            
            self._packedData.update(from: packedSchema,
                                    layerInputType: packedKeyPath,
                                    layerNode: layerNode,
                                    nodeId: nodeId,
                                    nodeDelegate: node)
        }
    }
}

extension InputLayerNodeRowData {
    /// Resets canvas data and connections when toggled between pack/unpack state.
    func resetOnPackModeToggle() {
        self.rowObserver.upstreamOutputCoordinate = nil
        self.canvasObserver = nil
    }
}

//enum UnpackedObserverType {
//    case position(LayerInputUnpackedPortPosition)
//}

//extension UnpackedObserverType {
//    func createSchema() -> [LayerInputDataEntity] {
//        // TODO: create schemas for unpacked
//        fatalError()
//    }
//    
//    @MainActor
//    var allPorts: [InputLayerNodeRowData] {
//        switch self {
//        case .position(let layerInputUnpackedPortPosition):
//            return layerInputUnpackedPortPosition.allPorts
//        }
//    }
//    
//    func getParentPortValuesList() -> PortValues {
//        switch self {
//        case .position(let layerInputUnpackedPortPosition):
//            return layerInputUnpackedPortPosition.getParentPortValuesList()
//        }
//    }
//    
//    @MainActor
//    func initializeDelegate(_ node: NodeDelegate) {
//        self.allPorts.forEach {
//            $0.initializeDelegate(node)
//        }
//    }
//}

//@Observable
//final class LayerInputUnpackedPortPosition {
//    let xPort: InputLayerNodeRowData
//    let yPort: InputLayerNodeRowData
//    
//    @MainActor
//    init(from schemas: [LayerInputDataEntity],
//         layer: Layer) {
//        assertInDebug(schemas.count == 2)
//        
//        self.xPort = .empty(.position(.unpacked(.port0)), layer: layer)
//        self.yPort = .empty(.position(.unpacked(.port1)), layer: layer)
//        
//        
//    }
//}

//extension LayerInputUnpackedPortPosition: LayerInputUnpackedPortObservable {
//    var allPorts: [InputLayerNodeRowData] {
//        [xPort, yPort]
//    }
//    
//    func getParentPortValuesList() -> PortValues {
//        fatalError()
//    }
//}

// primary = hidden via direct click from user
// secondary = hidden because was a child of a group that was primary-hidden
// none = not hidden at all

@Observable
final class LayerNodeViewModel {
    var id: NodeId

    var layer: Layer

    // View models for layers in prototype window
    var previewLayerViewModels: [LayerViewModel] = []
    
    // Some layer nodes contain outputs
    @MainActor var outputPorts: [OutputLayerNodeRowData] = []
    
    // TODO: temporarily using positionPort as only canvas item location until inspector is done
    
    @MainActor var positionPort: LayerInputObserver
    @MainActor var sizePort: InputLayerNodeRowData
    @MainActor var scalePort: InputLayerNodeRowData
    @MainActor var anchoringPort: InputLayerNodeRowData
    @MainActor var opacityPort: InputLayerNodeRowData
    @MainActor var zIndexPort: InputLayerNodeRowData
    @MainActor var masksPort: InputLayerNodeRowData
    @MainActor var colorPort: InputLayerNodeRowData
    @MainActor var startColorPort: InputLayerNodeRowData
    @MainActor var endColorPort: InputLayerNodeRowData
    @MainActor var startAnchorPort: InputLayerNodeRowData
    @MainActor var endAnchorPort: InputLayerNodeRowData
    @MainActor var centerAnchorPort: InputLayerNodeRowData
    @MainActor var startAnglePort: InputLayerNodeRowData
    @MainActor var endAnglePort: InputLayerNodeRowData
    @MainActor var startRadiusPort: InputLayerNodeRowData
    @MainActor var endRadiusPort: InputLayerNodeRowData
    @MainActor var rotationXPort: InputLayerNodeRowData
    @MainActor var rotationYPort: InputLayerNodeRowData
    @MainActor var rotationZPort: InputLayerNodeRowData
    @MainActor var lineColorPort: InputLayerNodeRowData
    @MainActor var lineWidthPort: InputLayerNodeRowData
    @MainActor var blurPort: InputLayerNodeRowData
    @MainActor var blendModePort: InputLayerNodeRowData
    @MainActor var brightnessPort: InputLayerNodeRowData
    @MainActor var colorInvertPort: InputLayerNodeRowData
    @MainActor var contrastPort: InputLayerNodeRowData
    @MainActor var hueRotationPort: InputLayerNodeRowData
    @MainActor var saturationPort: InputLayerNodeRowData
    @MainActor var pivotPort: InputLayerNodeRowData
    @MainActor var enabledPort: InputLayerNodeRowData
    @MainActor var blurRadiusPort: InputLayerNodeRowData
    @MainActor var backgroundColorPort: InputLayerNodeRowData
    @MainActor var isClippedPort: InputLayerNodeRowData
    @MainActor var orientationPort: InputLayerNodeRowData
    @MainActor var paddingPort: InputLayerNodeRowData
    @MainActor var setupModePort: InputLayerNodeRowData
    @MainActor var allAnchorsPort: InputLayerNodeRowData
    @MainActor var cameraDirectionPort: InputLayerNodeRowData
    @MainActor var isCameraEnabledPort: InputLayerNodeRowData
    @MainActor var isShadowsEnabledPort: InputLayerNodeRowData
    
    @MainActor var shapePort: InputLayerNodeRowData
    @MainActor var strokePositionPort: InputLayerNodeRowData
    @MainActor var strokeWidthPort: InputLayerNodeRowData
    @MainActor var strokeColorPort: InputLayerNodeRowData
    @MainActor var strokeStartPort: InputLayerNodeRowData
    @MainActor var strokeEndPort: InputLayerNodeRowData
    @MainActor var strokeLineCapPort: InputLayerNodeRowData
    @MainActor var strokeLineJoinPort: InputLayerNodeRowData
    @MainActor var coordinateSystemPort: InputLayerNodeRowData
    
    @MainActor var cornerRadiusPort: InputLayerNodeRowData
    @MainActor var canvasLineColorPort: InputLayerNodeRowData
    @MainActor var canvasLineWidthPort: InputLayerNodeRowData
    @MainActor var textPort: InputLayerNodeRowData
    @MainActor var fontSizePort: InputLayerNodeRowData
    @MainActor var textAlignmentPort: InputLayerNodeRowData
    @MainActor var verticalAlignmentPort: InputLayerNodeRowData
    @MainActor var textDecorationPort: InputLayerNodeRowData
    @MainActor var textFontPort: InputLayerNodeRowData
    @MainActor var imagePort: InputLayerNodeRowData
    @MainActor var videoPort: InputLayerNodeRowData
    @MainActor var fitStylePort: InputLayerNodeRowData
    @MainActor var clippedPort: InputLayerNodeRowData
    @MainActor var isAnimatingPort: InputLayerNodeRowData
    @MainActor var progressIndicatorStylePort: InputLayerNodeRowData
    @MainActor var progressPort: InputLayerNodeRowData
    @MainActor var model3DPort: InputLayerNodeRowData
    @MainActor var mapTypePort: InputLayerNodeRowData
    @MainActor var mapLatLongPort: InputLayerNodeRowData
    @MainActor var mapSpanPort: InputLayerNodeRowData
    @MainActor var isSwitchToggledPort: InputLayerNodeRowData
    @MainActor var placeholderTextPort: InputLayerNodeRowData
    
    @MainActor var shadowColorPort: InputLayerNodeRowData
    @MainActor var shadowOpacityPort: InputLayerNodeRowData
    @MainActor var shadowRadiusPort: InputLayerNodeRowData
    @MainActor var shadowOffsetPort: InputLayerNodeRowData
    @MainActor var sfSymbolPort: InputLayerNodeRowData
    
    @MainActor var videoURLPort: InputLayerNodeRowData
    @MainActor var volumePort: InputLayerNodeRowData
    
    @MainActor var spacingBetweenGridColumnsPort: InputLayerNodeRowData
    @MainActor var spacingBetweenGridRowsPort: InputLayerNodeRowData
    @MainActor var itemAlignmentWithinGridCellPort: InputLayerNodeRowData
    
    @MainActor var widthAxisPort: InputLayerNodeRowData
    @MainActor var heightAxisPort: InputLayerNodeRowData
    @MainActor var contentModePort: InputLayerNodeRowData
    @MainActor var minSizePort: InputLayerNodeRowData
    @MainActor var maxSizePort: InputLayerNodeRowData
    @MainActor var spacingPort: InputLayerNodeRowData
    @MainActor var sizingScenarioPort: InputLayerNodeRowData

    weak var nodeDelegate: NodeDelegate?

    // Sidebar visibility setting
    var hasSidebarVisibility = true {
        didSet {
            DispatchQueue.main.async { [weak self] in
                if let layerNode = self {
                    dispatch(AssignedLayerUpdated(changedLayerNode: layerNode.id.asLayerNodeId))
                }
            }
        }
    }

    var layerGroupId: NodeId? {
        didSet {
            DispatchQueue.main.async { [weak self] in
                if let layerNode = self {
                    dispatch(AssignedLayerUpdated(changedLayerNode: layerNode.id.asLayerNodeId))
                }
            }
        }
    }
    
    var isExpandedInSidebar: Bool?

    @MainActor
    init(from schema: LayerNodeEntity) {
        let graphNode = schema.layer.layerGraphNode
        
        // Create initial inputs and outputs using default data
        let rowDefinitions = NodeKind.layer(schema.layer)
            .rowDefinitions(for: nil)
        
        let rowFn = { (layerInput: LayerInputPort) -> InputLayerNodeRowData in
                .empty(.init(layerInput: layerInput,
                             portType: .packed),
                       layer: schema.layer)
        }
        
        self.id = schema.id
        self.layer = schema.layer
        self.hasSidebarVisibility = schema.hasSidebarVisibility
        self.layerGroupId = schema.layerGroupId
        self.isExpandedInSidebar = schema.isExpandedInSidebar
        
        self.outputPorts = rowDefinitions
            .createOutputLayerPorts(schema: schema,
                                    valuesList: rowDefinitions.outputs.defaultList,
                                    userVisibleType: nil)
        
        self.positionPort = .init(from: schema, port: .position)
        self.sizePort = rowFn(.size)
        self.scalePort = rowFn(.scale)
        self.anchoringPort = rowFn(.anchoring)
        self.opacityPort = rowFn(.opacity)
        self.zIndexPort = rowFn(.zIndex)
        self.masksPort = rowFn(.masks)
        self.colorPort = rowFn(.color)
        self.startColorPort = rowFn(.startColor)
        self.endColorPort = rowFn(.endColor)
        self.startAnchorPort = rowFn(.startAnchor)
        self.endAnchorPort = rowFn(.endAnchor)
        self.centerAnchorPort = rowFn(.centerAnchor)
        self.startAnglePort = rowFn(.startAngle)
        self.endAnglePort = rowFn(.endAngle)
        self.startRadiusPort = rowFn(.startRadius)
        self.endRadiusPort = rowFn(.endRadius)
        self.rotationXPort = rowFn(.rotationX)
        self.rotationYPort = rowFn(.rotationY)
        self.rotationZPort = rowFn(.rotationZ)
        self.lineColorPort = rowFn(.lineColor)
        self.lineWidthPort = rowFn(.lineWidth)
        self.blurPort = rowFn(.blur)
        self.blendModePort = rowFn(.blendMode)
        self.brightnessPort = rowFn(.brightness)
        self.colorInvertPort = rowFn(.colorInvert)
        self.contrastPort = rowFn(.contrast)
        self.hueRotationPort = rowFn(.hueRotation)
        self.saturationPort = rowFn(.saturation)
        self.pivotPort = rowFn(.pivot)
        self.enabledPort = rowFn(.enabled)
        self.blurRadiusPort = rowFn(.blurRadius)
        self.backgroundColorPort = rowFn(.backgroundColor)
        self.isClippedPort = rowFn(.isClipped)
        self.orientationPort = rowFn(.orientation)
        self.paddingPort = rowFn(.padding)
        self.setupModePort = rowFn(.setupMode)
        self.allAnchorsPort = rowFn(.allAnchors)
        self.cameraDirectionPort = rowFn(.cameraDirection)
        self.isCameraEnabledPort = rowFn(.isCameraEnabled)
        self.isShadowsEnabledPort = rowFn(.isShadowsEnabled)
        
        self.shapePort = rowFn(.shape)
        self.strokePositionPort = rowFn(.strokePosition)
        self.strokeWidthPort = rowFn(.strokeWidth)
        self.strokeColorPort = rowFn(.strokeColor)
        self.strokeStartPort = rowFn(.strokeStart)
        self.strokeEndPort = rowFn(.strokeEnd)
        self.strokeLineCapPort = rowFn(.strokeEnd)
        self.strokeLineJoinPort = rowFn(.strokeEnd)
        self.coordinateSystemPort = rowFn(.coordinateSystem)
        
        self.cornerRadiusPort = rowFn(.cornerRadius)
        self.canvasLineColorPort = rowFn(.canvasLineColor)
        self.canvasLineWidthPort = rowFn(.canvasLineWidth)
        self.textPort = rowFn(.text)
        self.fontSizePort = rowFn(.fontSize)
        self.textAlignmentPort = rowFn(.textAlignment)
        self.verticalAlignmentPort = rowFn(.verticalAlignment)
        self.textDecorationPort = rowFn(.textDecoration)
        self.textFontPort = rowFn(.textFont)
        self.imagePort = rowFn(.image)
        self.videoPort = rowFn(.video)
        self.fitStylePort = rowFn(.fitStyle)
        self.clippedPort = rowFn(.clipped)
        self.isAnimatingPort = rowFn(.isAnimating)
        self.progressIndicatorStylePort = rowFn(.progressIndicatorStyle)
        self.progressPort = rowFn(.progress)
        self.model3DPort = rowFn(.model3D)
        self.mapTypePort = rowFn(.mapType)
        self.mapLatLongPort = rowFn(.mapLatLong)
        self.mapSpanPort = rowFn(.mapSpan)
        self.isSwitchToggledPort = rowFn(.isSwitchToggled)
        self.placeholderTextPort = rowFn(.placeholderText)
        
        self.shadowColorPort = rowFn(.shadowColor)
        self.shadowOpacityPort = rowFn(.shadowOpacity)
        self.shadowRadiusPort = rowFn(.shadowRadius)
        self.shadowOffsetPort = rowFn(.shadowOffset)
        
        self.sfSymbolPort = rowFn(.sfSymbol)
        
        self.videoURLPort = rowFn(.videoURL)
        self.volumePort = rowFn(.volume)
        
        self.spacingBetweenGridColumnsPort = rowFn(.spacingBetweenGridColumns)
        self.spacingBetweenGridRowsPort = rowFn(.spacingBetweenGridRows)
        self.itemAlignmentWithinGridCellPort = rowFn(.itemAlignmentWithinGridCell)

        self.widthAxisPort = rowFn(.widthAxis)
        self.heightAxisPort = rowFn(.heightAxis)
        self.contentModePort = rowFn(.contentMode)
        self.minSizePort = rowFn(.minSize)
        self.maxSizePort = rowFn(.maxSize)
        self.spacingPort = rowFn(.spacing)
        self.sizingScenarioPort = rowFn(.sizingScenario)
        
        // Initialize each NodeRowObserver for each expected layer input
        for layerInputPort in graphNode.inputDefinitions {
            // Initialize packed port
            self.preinitializeSupportedPort(layerInputPort: layerInputPort,
                                            portType: .packed)
            
            // Check for ports which support unpacked state
            if let unpackedPortCount = layerInputPort.unpackedPortCount(layer: self.layer) {
                (0..<unpackedPortCount).forEach { unpackedPortId in
                    guard let unpackedPortType = UnpackedPortType(rawValue: unpackedPortId) else {
                        fatalErrorIfDebug("Expected to find unpacked port for \(unpackedPortId)")
                        return
                    }
                    
                    // Initialize unpacked port
                    self.preinitializeSupportedPort(layerInputPort: layerInputPort,
                                                    portType: .unpacked(unpackedPortType))
                }
            }
        }
        
        // Call update once everything above is in place
        for inputType in graphNode.inputDefinitions {
            self.initializePortSchema(layerSchema: schema,
                                      layerInputPort: inputType)
        }
    }
}

extension LayerNodeViewModel: SchemaObserver {
    @MainActor
    static func createObject(from entity: LayerNodeEntity) -> Self {
        .init(from: entity)
    }

    @MainActor
    func update(from schema: LayerNodeEntity) {
        if self.layer != schema.layer {
            self.layer = schema.layer
        }
        if self.hasSidebarVisibility != schema.hasSidebarVisibility {
            self.hasSidebarVisibility = schema.hasSidebarVisibility
        }
        if self.layerGroupId != schema.layerGroupId {
            self.layerGroupId = schema.layerGroupId
        }
        
        // Process input data
        self.layer.layerGraphNode.inputDefinitions.forEach {
            self[keyPath: $0.layerNodeKeyPath]
                .update(from: schema[keyPath: $0.schemaPortKeyPath],
                        layerInputType: $0,
                        layerNode: self,
                        nodeId: schema.id)
        }
        
        // Process output canvases
        self.updateOutputData(from: schema.outputCanvasPorts)
    }
    
    @MainActor
    /// Helper which discovers a layer node's inputs and passes its port into a callback.
    func forEachInput(_ callback: @escaping ((LayerInputObserver) -> ())) {
        self.layer.layerGraphNode.inputDefinitions.forEach {
            let port = self[keyPath: $0.layerNodeKeyPath]
            callback(port)
        }
    }
    
    @MainActor
    func updateOutputData(from canvases: [CanvasNodeEntity?]) {
        canvases.enumerated().forEach { portIndex, canvasEntity in
            guard let outputData = self.outputPorts[safe: portIndex],
                  let node = self.nodeDelegate else {
                fatalErrorIfDebug()
                return
            }
            
            let canvasViewModel = outputData.canvasObserver
            let coordinate = LayerOutputCoordinate(node: self.id,
                                                   portId: portIndex)
            
            // Create view model if not yet created (and should)
            guard let canvasViewModel = canvasViewModel else {
                if let canvasEntity = canvasEntity {
                    outputData.canvasObserver = CanvasItemViewModel(
                        from: canvasEntity,
                        id: .layerOutput(coordinate),
                        inputRowObservers: [],
                        outputRowObservers: [outputData.rowObserver])
                    outputData.canvasObserver?.initializeDelegate(node)
                }
                return
            }
            
            // Update canvas view model
            if let canvasEntity = canvasEntity {
                canvasViewModel.update(from: canvasEntity)
            }
            
            // Remove canvas view model
            else {
                outputData.canvasObserver = nil
            }
        }
    }

    func createSchema() -> LayerNodeEntity {
        var schema = LayerNodeEntity(nodeId: self.id,
                                     layer: layer,
                                     hasSidebarVisibility: hasSidebarVisibility,
                                     layerGroupId: layerGroupId,
                                     isExpandedInSidebar: self.isExpandedInSidebar)
        
        // Only encode keypaths used by this layer
        self.layer.layerGraphNode.inputDefinitions.forEach { inputType in
            schema[keyPath: inputType.schemaPortKeyPath] = self[keyPath: inputType.layerNodeKeyPath].createSchema()
        }
        
        // Save output canvas data
        schema.outputCanvasPorts = self.outputPorts.map {
            $0.canvasObserver?.createSchema()
        }
        
        return schema
    }
    
    func onPrototypeRestart() { }
}

extension LayerNodeViewModel {
    @MainActor
    func initializeDelegate(_ node: NodeDelegate) {
        let graphNode = self.layer.layerGraphNode
        let rowDefinitions = NodeKind.layer(self.layer)
            .rowDefinitions(for: nil)
        
        self.nodeDelegate = node
        
        // Set up outputs
        self.outputPorts.forEach {
            $0.initializeDelegate(node)
        }
        
        // Set up inputs
        for inputType in graphNode.inputDefinitions {
            let layerData = self[keyPath: inputType.layerNodeKeyPath]
            layerData.initializeDelegate(node)
        }
    }
    
    @MainActor
    func getAllCanvasObservers() -> [CanvasItemViewModel] {
        let inputs = self.layer.layerGraphNode.inputDefinitions.flatMap {
            self[keyPath: $0.layerNodeKeyPath].getAllCanvasObservers()
        }
        
        let outputs = self.outputPorts.compactMap {
            $0.canvasObserver
        }
        
        return inputs + outputs
    }
    
    @MainActor
    func getSortedInputPorts() -> [LayerInputObserver] {
        self.layer.layerGraphNode.inputDefinitions.map {
            self[keyPath: $0.layerNodeKeyPath]
        }
    }
    
    @MainActor
    func layerSize(_ activeIndex: ActiveIndex) -> LayerSize? {
        self.sizePort.rowObserver.activeValue.getSize
    }
    
    /// Updates one or more preview layers given some layer node.
    @MainActor
    func didValuesUpdate(newValuesList: PortValuesList,
                         id: NodeId) {

        let oldLongestLoopLength = self.previewLayerViewModels.count
        let newLongestLoopLength = self.nodeDelegate?.longestLoopLength ?? 1
        let loopIndices = newLongestLoopLength.loopIndices
        
        // Perf fix to calculate lengthened values from this parent context
        let lengthenedValuesList = newValuesList.map {
            $0.lengthenArray(newLongestLoopLength)
        }

        // Remove view models if loop count decreased
        if newLongestLoopLength < oldLongestLoopLength {
            self.previewLayerViewModels = Array(self.previewLayerViewModels[0..<newLongestLoopLength])
            
            // Re-sort preview layers when looping changes
            self.nodeDelegate?.graphDelegate?.shouldResortPreviewLayers = true
        }

        // Get preview layer view model given values loop index
        loopIndices.forEach { loopIndex in
            newValuesList.enumerated().forEach { portId, _ in
                // Save value diff check for delegate call below--
                // some nodes (like reality view) may ignore loops
                self.updatePreviewLayers(lengthenedValuesList: lengthenedValuesList,
                                         id: id,
                                         loopIndex: loopIndex,
                                         changedPortId: portId)
            }
        }

        #if DEBUG
        // Make sure we have the correct number of preview view models given loop
        if self.layer != .realityView {
            assert(newLongestLoopLength == self.previewLayerViewModels.count)
        }
        #endif
    }

    /// Gets/creates layer view model. Takes into consideration values from layer node and if we should (or shouldn't)
    /// create a new layer given some loop (i.e. the Reality layer node flattens anchors).
    @MainActor
    func updatePreviewLayers(lengthenedValuesList: PortValuesList,
                             id: NodeId,
                             loopIndex: Int,
                             changedPortId: Int) {
        let previewCoordinate = PreviewCoordinate(layerNodeId: id.asLayerNodeId,
                                                  loopIndex: loopIndex)
        // Always true except for inputs like Reality node's first input which accepts multiple anchors
        let doesPortSupportLooping = self.layer.doesPortSupportLooping(portId: changedPortId)

        // For ports like Reality node described above--ensures we only update on the
        // first loop index
        let isValidNonLoopingUpdate = !doesPortSupportLooping && loopIndex == 0

        // All conditions for supporting preview updates
        let shouldUpdatePreviewLayers = doesPortSupportLooping || isValidNonLoopingUpdate

        guard let previewViewModel = self.previewLayerViewModels[safe: loopIndex] else {
            // Don't support looping for certain ports which disable this (i.e. Reality node's first input)
            if doesPortSupportLooping {
                let newPreviewLayer = self.layer
                    .createPreviewLayerViewModel(id: previewCoordinate,
                                                 layer: self.layer,
                                                 lengthenedValuesList: lengthenedValuesList,
                                                 nodeDelegate: self.nodeDelegate)
                self.previewLayerViewModels.append(newPreviewLayer)
                
                // Re-sort preview layers when looping changes
                self.nodeDelegate?.graphDelegate?.shouldResortPreviewLayers = true
            }
            return
        }

        if shouldUpdatePreviewLayers {
            previewViewModel.update(with: lengthenedValuesList,
                                    changedPortId: changedPortId)
        }
    }
    
    var visibilityStatusIcon: String {
        self.hasSidebarVisibility
        ? SIDEBAR_VISIBILITY_STATUS_VISIBLE_ICON
        : SIDEBAR_VISIBILITY_STATUS_HIDDEN_ICON
    }
}

extension Layer {
    /// Creates view model for preview layer given a layer node and loop index.
    @MainActor
    func createPreviewLayerViewModel(id: PreviewCoordinate,
                                     layer: Layer,
                                     lengthenedValuesList: PortValuesList,
                                     nodeDelegate: NodeDelegate?) -> LayerViewModel {
        let viewModel = LayerViewModel(id: id,
                                       layer: layer,
                                       nodeDelegate: nodeDelegate)

        // Plug in values
        viewModel.updateAllValues(with: lengthenedValuesList)

        return viewModel
    }
}

extension LayerNodeViewModel {
    @MainActor
    func layerPosition(_ activeIndex: ActiveIndex) -> CGPoint? {
        self.positionPort.activeValue.getPoint
    }
    
    @MainActor
    func scaledLayerSize(for nodeId: NodeId,
                         parentSize: CGSize,
                         activeIndex: ActiveIndex) -> ScaledSize? {
        let scale = self.scalePort.rowObserver.activeValue.getNumber ?? .zero
        
        return self.sizePort.rowObserver.activeValue
            .getSize?.asCGSize(parentSize)
            .asScaledSize(scale)
    }
}
