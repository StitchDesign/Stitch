//
//  LayerNode.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/28/21.
//

import CoreData
import Foundation
import StitchSchemaKit
import SwiftUI

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
    var previewLayerViewModels: [LayerViewModel]
    
    // Some layer nodes contain outputs
    @MainActor var outputsObservers: NodeRowObservers = []
    
    @MainActor var positionPort: LayerNodeRowData
    @MainActor var sizePort: LayerNodeRowData
    @MainActor var scalePort: LayerNodeRowData
    @MainActor var anchoringPort: LayerNodeRowData
    @MainActor var opacityPort: LayerNodeRowData
    @MainActor var zIndexPort: LayerNodeRowData
    @MainActor var masksPort: LayerNodeRowData
    @MainActor var colorPort: LayerNodeRowData
    @MainActor var startColorPort: LayerNodeRowData
    @MainActor var endColorPort: LayerNodeRowData
    @MainActor var startAnchorPort: LayerNodeRowData
    @MainActor var endAnchorPort: LayerNodeRowData
    @MainActor var centerAnchorPort: LayerNodeRowData
    @MainActor var startAnglePort: LayerNodeRowData
    @MainActor var endAnglePort: LayerNodeRowData
    @MainActor var startRadiusPort: LayerNodeRowData
    @MainActor var endRadiusPort: LayerNodeRowData
    @MainActor var rotationXPort: LayerNodeRowData
    @MainActor var rotationYPort: LayerNodeRowData
    @MainActor var rotationZPort: LayerNodeRowData
    @MainActor var lineColorPort: LayerNodeRowData
    @MainActor var lineWidthPort: LayerNodeRowData
    @MainActor var blurPort: LayerNodeRowData
    @MainActor var blendModePort: LayerNodeRowData
    @MainActor var brightnessPort: LayerNodeRowData
    @MainActor var colorInvertPort: LayerNodeRowData
    @MainActor var contrastPort: LayerNodeRowData
    @MainActor var hueRotationPort: LayerNodeRowData
    @MainActor var saturationPort: LayerNodeRowData
    @MainActor var pivotPort: LayerNodeRowData
    @MainActor var enabledPort: LayerNodeRowData
    @MainActor var blurRadiusPort: LayerNodeRowData
    @MainActor var backgroundColorPort: LayerNodeRowData
    @MainActor var isClippedPort: LayerNodeRowData
    @MainActor var orientationPort: LayerNodeRowData
    @MainActor var paddingPort: LayerNodeRowData
    @MainActor var setupModePort: LayerNodeRowData
    @MainActor var allAnchorsPort: LayerNodeRowData
    @MainActor var cameraDirectionPort: LayerNodeRowData
    @MainActor var isCameraEnabledPort: LayerNodeRowData
    @MainActor var isShadowsEnabledPort: LayerNodeRowData
    
    @MainActor var shapePort: LayerNodeRowData
    @MainActor var strokePositionPort: LayerNodeRowData
    @MainActor var strokeWidthPort: LayerNodeRowData
    @MainActor var strokeColorPort: LayerNodeRowData
    @MainActor var strokeStartPort: LayerNodeRowData
    @MainActor var strokeEndPort: LayerNodeRowData
    @MainActor var strokeLineCapPort: LayerNodeRowData
    @MainActor var strokeLineJoinPort: LayerNodeRowData
    @MainActor var coordinateSystemPort: LayerNodeRowData
    
    @MainActor var cornerRadiusPort: LayerNodeRowData
    @MainActor var canvasLineColorPort: LayerNodeRowData
    @MainActor var canvasLineWidthPort: LayerNodeRowData
    @MainActor var textPort: LayerNodeRowData
    @MainActor var fontSizePort: LayerNodeRowData
    @MainActor var textAlignmentPort: LayerNodeRowData
    @MainActor var verticalAlignmentPort: LayerNodeRowData
    @MainActor var textDecorationPort: LayerNodeRowData
    @MainActor var textFontPort: LayerNodeRowData
    @MainActor var imagePort: LayerNodeRowData
    @MainActor var videoPort: LayerNodeRowData
    @MainActor var fitStylePort: LayerNodeRowData
    @MainActor var clippedPort: LayerNodeRowData
    @MainActor var isAnimatingPort: LayerNodeRowData
    @MainActor var progressIndicatorStylePort: LayerNodeRowData
    @MainActor var progressPort: LayerNodeRowData
    @MainActor var model3DPort: LayerNodeRowData
    @MainActor var mapTypePort: LayerNodeRowData
    @MainActor var mapLatLongPort: LayerNodeRowData
    @MainActor var mapSpanPort: LayerNodeRowData
    @MainActor var isSwitchToggledPort: LayerNodeRowData
    @MainActor var placeholderTextPort: LayerNodeRowData
    
    @MainActor var shadowColorPort: LayerNodeRowData
    @MainActor var shadowOpacityPort: LayerNodeRowData
    @MainActor var shadowRadiusPort: LayerNodeRowData
    @MainActor var shadowOffsetPort: LayerNodeRowData
    @MainActor var sfSymbolPort: LayerNodeRowData
    
    @MainActor var videoURLPort: LayerNodeRowData
    @MainActor var volumePort: LayerNodeRowData
    
    @MainActor var spacingBetweenGridColumnsPort: LayerNodeRowData
    @MainActor var spacingBetweenGridRowsPort: LayerNodeRowData
    @MainActor var itemAlignmentWithinGridCellPort: LayerNodeRowData

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
    init(from schema: LayerNodeEntity,
         nodeDelegate: NodeDelegate?) {
        // Create initial inputs and outputs using default data
        let rowDefinitions = NodeKind.layer(schema.layer)
            .rowDefinitions(for: nil)
        
        self.id = schema.id
        self.layer = schema.layer
        
        self.hasSidebarVisibility = schema.hasSidebarVisibility
        self.layerGroupId = schema.layerGroupId
        self.isExpandedInSidebar = schema.isExpandedInSidebar
        
        self.outputsObservers = rowDefinitions
            .createOutputObservers(nodeId: schema.id,
                                   values: rowDefinitions.outputs.defaultList,
                                   kind: .layer(schema.layer),
                                   userVisibleType: nil,
                                   nodeDelegate: nodeDelegate)
        
        self.positionPort = .empty(.position, layer: schema.layer)
        self.sizePort = .empty(.size, layer: schema.layer)
        self.scalePort = .empty(.scale, layer: schema.layer)
        self.anchoringPort = .empty(.anchoring, layer: schema.layer)
        self.opacityPort = .empty(.opacity, layer: schema.layer)
        self.zIndexPort = .empty(.zIndex, layer: schema.layer)
        self.masksPort = .empty(.masks, layer: schema.layer)
        self.colorPort = .empty(.color, layer: schema.layer)
        self.startColorPort = .empty(.startColor, layer: schema.layer)
        self.endColorPort = .empty(.endColor, layer: schema.layer)
        self.startAnchorPort = .empty(.startAnchor, layer: schema.layer)
        self.endAnchorPort = .empty(.endAnchor, layer: schema.layer)
        self.centerAnchorPort = .empty(.centerAnchor, layer: schema.layer)
        self.startAnglePort = .empty(.startAngle, layer: schema.layer)
        self.endAnglePort = .empty(.endAngle, layer: schema.layer)
        self.startRadiusPort = .empty(.startRadius, layer: schema.layer)
        self.endRadiusPort = .empty(.endRadius, layer: schema.layer)
        self.rotationXPort = .empty(.rotationX, layer: schema.layer)
        self.rotationYPort = .empty(.rotationY, layer: schema.layer)
        self.rotationZPort = .empty(.rotationZ, layer: schema.layer)
        self.lineColorPort = .empty(.lineColor, layer: schema.layer)
        self.lineWidthPort = .empty(.lineWidth, layer: schema.layer)
        self.blurPort = .empty(.blur, layer: schema.layer)
        self.blendModePort = .empty(.blendMode, layer: schema.layer)
        self.brightnessPort = .empty(.brightness, layer: schema.layer)
        self.colorInvertPort = .empty(.colorInvert, layer: schema.layer)
        self.contrastPort = .empty(.contrast, layer: schema.layer)
        self.hueRotationPort = .empty(.hueRotation, layer: schema.layer)
        self.saturationPort = .empty(.saturation, layer: schema.layer)
        self.pivotPort = .empty(.pivot, layer: schema.layer)
        self.enabledPort = .empty(.enabled, layer: schema.layer)
        self.blurRadiusPort = .empty(.blurRadius, layer: schema.layer)
        self.backgroundColorPort = .empty(.backgroundColor, layer: schema.layer)
        self.isClippedPort = .empty(.isClipped, layer: schema.layer)
        self.orientationPort = .empty(.orientation, layer: schema.layer)
        self.paddingPort = .empty(.padding, layer: schema.layer)
        self.setupModePort = .empty(.setupMode, layer: schema.layer)
        self.allAnchorsPort = .empty(.allAnchors, layer: schema.layer)
        self.cameraDirectionPort = .empty(.cameraDirection, layer: schema.layer)
        self.isCameraEnabledPort = .empty(.isCameraEnabled, layer: schema.layer)
        self.isShadowsEnabledPort = .empty(.isShadowsEnabled, layer: schema.layer)
        
        self.shapePort = .empty(.shape, layer: schema.layer)
        self.strokePositionPort = .empty(.strokePosition, layer: schema.layer)
        self.strokeWidthPort = .empty(.strokeWidth, layer: schema.layer)
        self.strokeColorPort = .empty(.strokeColor, layer: schema.layer)
        self.strokeStartPort = .empty(.strokeStart, layer: schema.layer)
        self.strokeEndPort = .empty(.strokeEnd, layer: schema.layer)
        self.strokeLineCapPort = .empty(.strokeEnd, layer: schema.layer)
        self.strokeLineJoinPort = .empty(.strokeEnd, layer: schema.layer)
        self.coordinateSystemPort = .empty(.coordinateSystem, layer: schema.layer)
        
        self.cornerRadiusPort = .empty(.cornerRadius, layer: schema.layer)
        self.canvasLineColorPort = .empty(.canvasLineColor, layer: schema.layer)
        self.canvasLineWidthPort = .empty(.canvasLineWidth, layer: schema.layer)
        self.textPort = .empty(.text, layer: schema.layer)
        self.fontSizePort = .empty(.fontSize, layer: schema.layer)
        self.textAlignmentPort = .empty(.textAlignment, layer: schema.layer)
        self.verticalAlignmentPort = .empty(.verticalAlignment, layer: schema.layer)
        self.textDecorationPort = .empty(.textDecoration, layer: schema.layer)
        self.textFontPort = .empty(.textFont, layer: schema.layer)
        self.imagePort = .empty(.image, layer: schema.layer)
        self.videoPort = .empty(.video, layer: schema.layer)
        self.fitStylePort = .empty(.fitStyle, layer: schema.layer)
        self.clippedPort = .empty(.clipped, layer: schema.layer)
        self.isAnimatingPort = .empty(.isAnimating, layer: schema.layer)
        self.progressIndicatorStylePort = .empty(.progressIndicatorStyle, layer: schema.layer)
        self.progressPort = .empty(.progress, layer: schema.layer)
        self.model3DPort = .empty(.model3D, layer: schema.layer)
        self.mapTypePort = .empty(.mapType, layer: schema.layer)
        self.mapLatLongPort = .empty(.mapLatLong, layer: schema.layer)
        self.mapSpanPort = .empty(.mapSpan, layer: schema.layer)
        self.isSwitchToggledPort = .empty(.isSwitchToggled, layer: schema.layer)
        self.placeholderTextPort = .empty(.placeholderText, layer: schema.layer)
        
        self.shadowColorPort = .empty(.shadowColor, layer: schema.layer)
        self.shadowOpacityPort = .empty(.shadowOpacity, layer: schema.layer)
        self.shadowRadiusPort = .empty(.shadowRadius, layer: schema.layer)
        self.shadowOffsetPort = .empty(.shadowOffset, layer: schema.layer)
        
        self.sfSymbolPort = .empty(.sfSymbol, layer: schema.layer)
        
        self.videoURLPort = .empty(.videoURL, layer: schema.layer)
        self.volumePort = .empty(.volume, layer: schema.layer)
        
        self.spacingBetweenGridColumnsPort = .empty(.spacingBetweenGridColumns, layer: schema.layer)
        self.spacingBetweenGridRowsPort = .empty(.spacingBetweenGridRows, layer: schema.layer)
        self.itemAlignmentWithinGridCellPort = .empty(.itemAlignmentWithinGridCell, layer: schema.layer)

        let graphNode = schema.layer.layerGraphNode
        
        // Note: this should never actually be empty; only empty here as part of initialization; populated by a later call to `LayerNodeViewModel.didValuesUpdate`
        self.previewLayerViewModels = .init()
        
        // TODO: use the serialized data rather than default inputs which we override anyway
        // Initialize each NodeRowObserver for each expected layer input
        for inputType in graphNode.inputDefinitions {
            let id = NodeIOCoordinate(portType: .keyPath(inputType), nodeId: schema.id)
            let rowObserver = self[keyPath: inputType.layerNodeKeyPath].rowObserver
            
            rowObserver.nodeKind = .layer(schema.layer)
            rowObserver.nodeDelegate = nodeDelegate
            rowObserver.id = id
        }
    }
}

extension LayerNodeViewModel: SchemaObserver {
    static func createObject(from entity: LayerNodeEntity) -> Self {
        .init(from: entity,
              nodeDelegate: nil)
    }

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
            self[keyPath: $0.layerNodeKeyPath].rowObserver
                .update(from: schema[keyPath: $0.schemaPortKeyPath],
                        inputType: $0)
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
            schema[keyPath: inputType.schemaPortKeyPath] = self[keyPath: inputType.layerNodeKeyPath].rowObserver.createLayerSchema()
        }
        
        return schema
    }
    
    func onPrototypeRestart() { }
}

extension LayerNodeViewModel {
    func getAllCanvasObservers() -> [CanvasNodeViewModel] {
        fatalError()
        /// Steps here...
        /// 1. Get layer definition
        /// 2. Iterate over each input in the layer definition
    }
    
    @MainActor
    func getSortedInputObservers() -> NodeRowObservers {
        self.layer.layerGraphNode.inputDefinitions.map {
            self[keyPath: $0.layerNodeKeyPath].rowObserver
        }
    }
    
    @MainActor
    func layerSize(_ activeIndex: ActiveIndex) -> LayerSize? {
        self.sizePort.rowObserver
            .getActiveValue(activeIndex: activeIndex).getSize
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
        self.positionPort.rowObserver
            .getActiveValue(activeIndex: activeIndex).getPoint
    }
    
    @MainActor
    func scaledLayerSize(for nodeId: NodeId,
                         parentSize: CGSize,
                         activeIndex: ActiveIndex) -> ScaledSize? {
        let scale = self.scalePort.rowObserver
            .getActiveValue(activeIndex: activeIndex).getNumber ?? .zero
        
        return self.sizePort.rowObserver
            .getActiveValue(activeIndex: activeIndex)
            .getSize?.asCGSize(parentSize)
            .asScaledSize(scale)
    }
}
