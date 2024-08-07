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
    var port0: InputLayerNodeRowData
    var port1: InputLayerNodeRowData
    var port2: InputLayerNodeRowData
    
    init(port0: InputLayerNodeRowData, port1: InputLayerNodeRowData, port2: InputLayerNodeRowData) {
        self.port0 = port0
        self.port1 = port1
        self.port2 = port2
    }
}

extension LayerInputUnpackedPortObserver {
    @MainActor
    func getParentPortValuesList() -> PortValues {
        fatalError()
    }
    
    @MainActor
    var allPorts: [InputLayerNodeRowData] {
        // needs input type to consider how many ports are used
        fatalError()
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
}

///// Needs to be class for StitchEngine which assumes reference objects with its mutation logic
//final class LayerInputObserver {
//    var id: NodeIOCoordinate    // ID used for NodeRowCalculatable
//    var type: LayerInputObserverMode
//    
//    init(id: NodeIOCoordinate,
//         type: LayerInputObserverMode) {
//        self.id = id
//        self.type = type
//    }
//}

// Must be a class for coordinate keypaths, which expect a reference type on the other end.
final class LayerInputObserver {
    // Not intended to be used as an API given both data payloads always exist
    // Variables here necessary to ensure keypaths logic works
    var _packedData: InputLayerNodeRowData
    var _unpackedData: LayerInputUnpackedPortObserver
    
    var mode: LayerInputObserverMode = .packed
    
    @MainActor
    init(from schema: LayerNodeEntity, packedInputType: LayerInputType) {
        self._packedData = .empty(packedInputType, layer: schema.layer)
    }
}

enum LayerInputObserverMode {
    case packed
    case unpacked
}

extension LayerInputObserver {
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
    var allInputData: [InputLayerNodeRowData] {
        switch self.mode {
        case .packed:
            return [self._packedData]
        case .unpacked:
            return self._unpackedData.allPorts
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
        switch self.mode {
        case .packed:
            if let canvas = self._packedData.canvasObserver {
                return [canvas]
            }
        case .unpacked:
            return self._unpackedData.allPorts.compactMap {
                $0.canvasObserver
            }
        }
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
                .empty(layerInput,
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
        
        self.positionPort = .init(from: schema, packedInputType: .position(.packed))
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
        for inputType in graphNode.inputDefinitions {
            let id = NodeIOCoordinate(portType: .keyPath(inputType), nodeId: self.id)
            
            // expect packed case on initialization
            guard let layerData: InputLayerNodeRowData = self[keyPath: inputType.layerNodeKeyPath].packedObserver else {
                fatalErrorIfDebug()
                return
            }
            
            // Update row view model ID
            layerData.inspectorRowViewModel.id = .init(graphItemType: .layerInspector(inputType),
                                                       nodeId: id.nodeId,
                                                       portId: 0)
            
            // Update row observer
            layerData.rowObserver.nodeKind = .layer(self.layer)
            layerData.rowObserver.id = id
        }
        
        // Call update once everything above is in place
        for inputType in graphNode.inputDefinitions {
            let layerData: LayerInputObserverMode = self[keyPath: inputType.layerNodeKeyPath]
            
            layerData.update(from: schema[keyPath: inputType.schemaPortKeyPath],
                             layerInputType: inputType,
                             layerNode: self,
                             nodeId: schema.id)
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
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return
        }
        
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
    func getSortedInputObservers() -> [InputNodeRowObserver] {
        self.layer.layerGraphNode.inputDefinitions.map {
            self[keyPath: $0.layerNodeKeyPath].rowObserver
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
        self.positionPort
            .rowObserver.activeValue.getPoint
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
