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
    @MainActor var sizePort: LayerInputObserver
    @MainActor var scalePort: LayerInputObserver
    @MainActor var anchoringPort: LayerInputObserver
    @MainActor var opacityPort: LayerInputObserver
    @MainActor var zIndexPort: LayerInputObserver
    @MainActor var masksPort: LayerInputObserver
    @MainActor var colorPort: LayerInputObserver
    @MainActor var startColorPort: LayerInputObserver
    @MainActor var endColorPort: LayerInputObserver
    @MainActor var startAnchorPort: LayerInputObserver
    @MainActor var endAnchorPort: LayerInputObserver
    @MainActor var centerAnchorPort: LayerInputObserver
    @MainActor var startAnglePort: LayerInputObserver
    @MainActor var endAnglePort: LayerInputObserver
    @MainActor var startRadiusPort: LayerInputObserver
    @MainActor var endRadiusPort: LayerInputObserver
    @MainActor var rotationXPort: LayerInputObserver
    @MainActor var rotationYPort: LayerInputObserver
    @MainActor var rotationZPort: LayerInputObserver
    @MainActor var lineColorPort: LayerInputObserver
    @MainActor var lineWidthPort: LayerInputObserver
    @MainActor var blurPort: LayerInputObserver
    @MainActor var blendModePort: LayerInputObserver
    @MainActor var brightnessPort: LayerInputObserver
    @MainActor var colorInvertPort: LayerInputObserver
    @MainActor var contrastPort: LayerInputObserver
    @MainActor var hueRotationPort: LayerInputObserver
    @MainActor var saturationPort: LayerInputObserver
    @MainActor var pivotPort: LayerInputObserver
    @MainActor var enabledPort: LayerInputObserver
    @MainActor var blurRadiusPort: LayerInputObserver
    @MainActor var backgroundColorPort: LayerInputObserver
    @MainActor var isClippedPort: LayerInputObserver
    @MainActor var orientationPort: LayerInputObserver
    @MainActor var paddingPort: LayerInputObserver
    @MainActor var setupModePort: LayerInputObserver
    @MainActor var allAnchorsPort: LayerInputObserver
    @MainActor var cameraDirectionPort: LayerInputObserver
    @MainActor var isCameraEnabledPort: LayerInputObserver
    @MainActor var isShadowsEnabledPort: LayerInputObserver
    
    @MainActor var shapePort: LayerInputObserver
    @MainActor var strokePositionPort: LayerInputObserver
    @MainActor var strokeWidthPort: LayerInputObserver
    @MainActor var strokeColorPort: LayerInputObserver
    @MainActor var strokeStartPort: LayerInputObserver
    @MainActor var strokeEndPort: LayerInputObserver
    @MainActor var strokeLineCapPort: LayerInputObserver
    @MainActor var strokeLineJoinPort: LayerInputObserver
    @MainActor var coordinateSystemPort: LayerInputObserver
    
    @MainActor var cornerRadiusPort: LayerInputObserver
    @MainActor var canvasLineColorPort: LayerInputObserver
    @MainActor var canvasLineWidthPort: LayerInputObserver
    @MainActor var textPort: LayerInputObserver
    @MainActor var fontSizePort: LayerInputObserver
    @MainActor var textAlignmentPort: LayerInputObserver
    @MainActor var verticalAlignmentPort: LayerInputObserver
    @MainActor var textDecorationPort: LayerInputObserver
    @MainActor var textFontPort: LayerInputObserver
    @MainActor var imagePort: LayerInputObserver
    @MainActor var videoPort: LayerInputObserver
    @MainActor var fitStylePort: LayerInputObserver
    @MainActor var clippedPort: LayerInputObserver
    @MainActor var isAnimatingPort: LayerInputObserver
    @MainActor var progressIndicatorStylePort: LayerInputObserver
    @MainActor var progressPort: LayerInputObserver
    @MainActor var model3DPort: LayerInputObserver
    @MainActor var mapTypePort: LayerInputObserver
    @MainActor var mapLatLongPort: LayerInputObserver
    @MainActor var mapSpanPort: LayerInputObserver
    @MainActor var isSwitchToggledPort: LayerInputObserver
    @MainActor var placeholderTextPort: LayerInputObserver
    
    @MainActor var shadowColorPort: LayerInputObserver
    @MainActor var shadowOpacityPort: LayerInputObserver
    @MainActor var shadowRadiusPort: LayerInputObserver
    @MainActor var shadowOffsetPort: LayerInputObserver
    @MainActor var sfSymbolPort: LayerInputObserver
    
    @MainActor var videoURLPort: LayerInputObserver
    @MainActor var volumePort: LayerInputObserver
    
    @MainActor var spacingBetweenGridColumnsPort: LayerInputObserver
    @MainActor var spacingBetweenGridRowsPort: LayerInputObserver
    @MainActor var itemAlignmentWithinGridCellPort: LayerInputObserver
    
    @MainActor var widthAxisPort: LayerInputObserver
    @MainActor var heightAxisPort: LayerInputObserver
    @MainActor var contentModePort: LayerInputObserver
    @MainActor var minSizePort: LayerInputObserver
    @MainActor var maxSizePort: LayerInputObserver
    @MainActor var spacingPort: LayerInputObserver
    @MainActor var sizingScenarioPort: LayerInputObserver

    @MainActor var isPinnedPort: LayerInputObserver
    @MainActor var pinToPort: LayerInputObserver
    @MainActor var pinAnchorPort: LayerInputObserver
    @MainActor var pinOffsetPort: LayerInputObserver
    
    @MainActor var layerMarginPort: LayerInputObserver
    @MainActor var layerPaddingPort: LayerInputObserver
    @MainActor var offsetInGroupPort: LayerInputObserver
    
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
        self.sizePort = .init(from: schema, port: .size)
        self.scalePort = .init(from: schema, port: .scale)
        self.anchoringPort = .init(from: schema, port: .anchoring)
        self.opacityPort = .init(from: schema, port: .opacity)
        self.zIndexPort = .init(from: schema, port: .zIndex)
        self.masksPort = .init(from: schema, port: .masks)
        self.colorPort = .init(from: schema, port: .color)
        self.startColorPort = .init(from: schema, port: .startColor)
        self.endColorPort = .init(from: schema, port: .endColor)
        self.startAnchorPort = .init(from: schema, port: .startAnchor)
        self.endAnchorPort = .init(from: schema, port: .endAnchor)
        self.centerAnchorPort = .init(from: schema, port: .centerAnchor)
        self.startAnglePort = .init(from: schema, port: .startAngle)
        self.endAnglePort = .init(from: schema, port: .endAngle)
        self.startRadiusPort = .init(from: schema, port: .startRadius)
        self.endRadiusPort = .init(from: schema, port: .endRadius)
        self.rotationXPort = .init(from: schema, port: .rotationX)
        self.rotationYPort = .init(from: schema, port: .rotationY)
        self.rotationZPort = .init(from: schema, port: .rotationZ)
        self.lineColorPort = .init(from: schema, port: .lineColor)
        self.lineWidthPort = .init(from: schema, port: .lineWidth)
        self.blurPort = .init(from: schema, port: .blur)
        self.blendModePort = .init(from: schema, port: .blendMode)
        self.brightnessPort = .init(from: schema, port: .brightness)
        self.colorInvertPort = .init(from: schema, port: .colorInvert)
        self.contrastPort = .init(from: schema, port: .contrast)
        self.hueRotationPort = .init(from: schema, port: .hueRotation)
        self.saturationPort = .init(from: schema, port: .saturation)
        self.pivotPort = .init(from: schema, port: .pivot)
        self.enabledPort = .init(from: schema, port: .enabled)
        self.blurRadiusPort = .init(from: schema, port: .blurRadius)
        self.backgroundColorPort = .init(from: schema, port: .backgroundColor)
        self.isClippedPort = .init(from: schema, port: .isClipped)
        self.orientationPort = .init(from: schema, port: .orientation)
        self.paddingPort = .init(from: schema, port: .padding)
        self.setupModePort = .init(from: schema, port: .setupMode)
        self.allAnchorsPort = .init(from: schema, port: .allAnchors)
        self.cameraDirectionPort = .init(from: schema, port: .cameraDirection)
        self.isCameraEnabledPort = .init(from: schema, port: .isCameraEnabled)
        self.isShadowsEnabledPort = .init(from: schema, port: .isShadowsEnabled)
        
        self.shapePort = .init(from: schema, port: .shape)
        self.strokePositionPort = .init(from: schema, port: .strokePosition)
        self.strokeWidthPort = .init(from: schema, port: .strokeWidth)
        self.strokeColorPort = .init(from: schema, port: .strokeColor)
        self.strokeStartPort = .init(from: schema, port: .strokeStart)
        self.strokeEndPort = .init(from: schema, port: .strokeEnd)
        self.strokeLineCapPort = .init(from: schema, port: .strokeEnd)
        self.strokeLineJoinPort = .init(from: schema, port: .strokeEnd)
        self.coordinateSystemPort = .init(from: schema, port: .coordinateSystem)
        
        self.cornerRadiusPort = .init(from: schema, port: .cornerRadius)
        self.canvasLineColorPort = .init(from: schema, port: .canvasLineColor)
        self.canvasLineWidthPort = .init(from: schema, port: .canvasLineWidth)
        self.textPort = .init(from: schema, port: .text)
        self.fontSizePort = .init(from: schema, port: .fontSize)
        self.textAlignmentPort = .init(from: schema, port: .textAlignment)
        self.verticalAlignmentPort = .init(from: schema, port: .verticalAlignment)
        self.textDecorationPort = .init(from: schema, port: .textDecoration)
        self.textFontPort = .init(from: schema, port: .textFont)
        self.imagePort = .init(from: schema, port: .image)
        self.videoPort = .init(from: schema, port: .video)
        self.fitStylePort = .init(from: schema, port: .fitStyle)
        self.clippedPort = .init(from: schema, port: .clipped)
        self.isAnimatingPort = .init(from: schema, port: .isAnimating)
        self.progressIndicatorStylePort = .init(from: schema, port: .progressIndicatorStyle)
        self.progressPort = .init(from: schema, port: .progress)
        self.model3DPort = .init(from: schema, port: .model3D)
        self.mapTypePort = .init(from: schema, port: .mapType)
        self.mapLatLongPort = .init(from: schema, port: .mapLatLong)
        self.mapSpanPort = .init(from: schema, port: .mapSpan)
        self.isSwitchToggledPort = .init(from: schema, port: .isSwitchToggled)
        self.placeholderTextPort = .init(from: schema, port: .placeholderText)
        
        self.shadowColorPort = .init(from: schema, port: .shadowColor)
        self.shadowOpacityPort = .init(from: schema, port: .shadowOpacity)
        self.shadowRadiusPort = .init(from: schema, port: .shadowRadius)
        self.shadowOffsetPort = .init(from: schema, port: .shadowOffset)
        
        self.sfSymbolPort = .init(from: schema, port: .sfSymbol)
        
        self.videoURLPort = .init(from: schema, port: .videoURL)
        self.volumePort = .init(from: schema, port: .volume)
        
        self.spacingBetweenGridColumnsPort = .init(from: schema, port: .spacingBetweenGridColumns)
        self.spacingBetweenGridRowsPort = .init(from: schema, port: .spacingBetweenGridRows)
        self.itemAlignmentWithinGridCellPort = .init(from: schema, port: .itemAlignmentWithinGridCell)

        self.widthAxisPort = .init(from: schema, port: .widthAxis)
        self.heightAxisPort = .init(from: schema, port: .heightAxis)
        self.contentModePort = .init(from: schema, port: .contentMode)
        self.minSizePort = .init(from: schema, port: .minSize)
        self.maxSizePort = .init(from: schema, port: .maxSize)
        self.spacingPort = .init(from: schema, port: .spacing)
        self.sizingScenarioPort = .init(from: schema, port: .sizingScenario)
        
        self.isPinnedPort = .init(from: schema, port: .isPinned)
        self.pinToPort = .init(from: schema, port: .pinTo)
        self.pinAnchorPort = .init(from: schema, port: .pinAnchor)
        self.pinOffsetPort = .init(from: schema, port: .pinOffset)
        
        self.layerPaddingPort = .init(from: schema, port: .layerPadding)
        self.layerMarginPort = .init(from: schema, port: .layerMargin)
        self.offsetInGroupPort = .init(from: schema, port: .offsetInGroup)
        
        // Initialize each NodeRowObserver for each expected layer input
        for layerInputPort in graphNode.inputDefinitions {
            // Initialize packed port
            self.preinitializeSupportedPort(layerInputPort: layerInputPort,
                                            portType: .packed)
            
            // Check for ports which support unpacked state
            if FeatureFlags.SUPPORTS_LAYER_UNPACK {
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
                        outputRowObservers: [outputData.rowObserver],
                        // Not relevant
                        unpackedPortParentFieldGroupType: nil,
                        unpackedPortIndex: nil)
                    
                    outputData.canvasObserver?.initializeDelegate(node,
                                                                  // Not relevant
                                                                  unpackedPortParentFieldGroupType: nil,
                                                                  unpackedPortIndex: nil)
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
        self.nodeDelegate = node
        
        // Set up outputs
        self.outputPorts.forEach {
            $0.initializeDelegate(node)
        }
        
        // Set up inputs
        self.forEachInput { layerInput in
            layerInput.initializeDelegate(node,
                                          layer: self.layer)
        }
        
        // Set blocked fields after all fields have been initialized
        self.forEachInput { layerInput in
            node.blockOrUnblockFields(newValue: layerInput.activeValue,
                                      layerInput: layerInput.port)
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
        self.sizePort.activeValue.getSize
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
        let scale = self.scalePort.activeValue.getNumber ?? .zero
        
        return self.sizePort.activeValue
            .getSize?.asCGSize(parentSize)
            .asScaledSize(scale)
    }
}
