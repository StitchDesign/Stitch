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
    
    @MainActor var positionPort: NodeRowObserver
    @MainActor var sizePort: NodeRowObserver
    @MainActor var scalePort: NodeRowObserver
    @MainActor var anchoringPort: NodeRowObserver
    @MainActor var opacityPort: NodeRowObserver
    @MainActor var zIndexPort: NodeRowObserver
    @MainActor var masksPort: NodeRowObserver
    @MainActor var colorPort: NodeRowObserver
    @MainActor var startColorPort: NodeRowObserver
    @MainActor var endColorPort: NodeRowObserver
    @MainActor var startAnchorPort: NodeRowObserver
    @MainActor var endAnchorPort: NodeRowObserver
    @MainActor var centerAnchorPort: NodeRowObserver
    @MainActor var startAnglePort: NodeRowObserver
    @MainActor var endAnglePort: NodeRowObserver
    @MainActor var startRadiusPort: NodeRowObserver
    @MainActor var endRadiusPort: NodeRowObserver
    @MainActor var rotationXPort: NodeRowObserver
    @MainActor var rotationYPort: NodeRowObserver
    @MainActor var rotationZPort: NodeRowObserver
    @MainActor var lineColorPort: NodeRowObserver
    @MainActor var lineWidthPort: NodeRowObserver
    @MainActor var blurPort: NodeRowObserver
    @MainActor var blendModePort: NodeRowObserver
    @MainActor var brightnessPort: NodeRowObserver
    @MainActor var colorInvertPort: NodeRowObserver
    @MainActor var contrastPort: NodeRowObserver
    @MainActor var hueRotationPort: NodeRowObserver
    @MainActor var saturationPort: NodeRowObserver
    @MainActor var pivotPort: NodeRowObserver
    @MainActor var enabledPort: NodeRowObserver
    @MainActor var blurRadiusPort: NodeRowObserver
    @MainActor var backgroundColorPort: NodeRowObserver
    @MainActor var isClippedPort: NodeRowObserver
    @MainActor var orientationPort: NodeRowObserver
    @MainActor var paddingPort: NodeRowObserver
    @MainActor var setupModePort: NodeRowObserver
    @MainActor var allAnchorsPort: NodeRowObserver
    @MainActor var cameraDirectionPort: NodeRowObserver
    @MainActor var isCameraEnabledPort: NodeRowObserver
    @MainActor var isShadowsEnabledPort: NodeRowObserver
    
    @MainActor var shapePort: NodeRowObserver
    @MainActor var strokePositionPort: NodeRowObserver
    @MainActor var strokeWidthPort: NodeRowObserver
    @MainActor var strokeColorPort: NodeRowObserver
    @MainActor var strokeStartPort: NodeRowObserver
    @MainActor var strokeEndPort: NodeRowObserver
    @MainActor var strokeLineCapPort: NodeRowObserver
    @MainActor var strokeLineJoinPort: NodeRowObserver
    @MainActor var coordinateSystemPort: NodeRowObserver
    
    @MainActor var cornerRadiusPort: NodeRowObserver
    @MainActor var canvasLineColorPort: NodeRowObserver
    @MainActor var canvasLineWidthPort: NodeRowObserver
    @MainActor var textPort: NodeRowObserver
    @MainActor var fontSizePort: NodeRowObserver
    @MainActor var textAlignmentPort: NodeRowObserver
    @MainActor var verticalAlignmentPort: NodeRowObserver
    @MainActor var textDecorationPort: NodeRowObserver
    @MainActor var textFontPort: NodeRowObserver
    @MainActor var imagePort: NodeRowObserver
    @MainActor var videoPort: NodeRowObserver
    @MainActor var fitStylePort: NodeRowObserver
    @MainActor var clippedPort: NodeRowObserver
    @MainActor var isAnimatingPort: NodeRowObserver
    @MainActor var progressIndicatorStylePort: NodeRowObserver
    @MainActor var progressPort: NodeRowObserver
    @MainActor var model3DPort: NodeRowObserver
    @MainActor var mapTypePort: NodeRowObserver
    @MainActor var mapLatLongPort: NodeRowObserver
    @MainActor var mapSpanPort: NodeRowObserver
    @MainActor var isSwitchToggledPort: NodeRowObserver
    @MainActor var placeholderTextPort: NodeRowObserver
    
    @MainActor var shadowColorPort: NodeRowObserver
    @MainActor var shadowOpacityPort: NodeRowObserver
    @MainActor var shadowRadiusPort: NodeRowObserver
    @MainActor var shadowOffsetPort: NodeRowObserver
    @MainActor var sfSymbolPort: NodeRowObserver
    
    @MainActor var videoURLPort: NodeRowObserver
    @MainActor var volumePort: NodeRowObserver
    
    @MainActor var spacingBetweenGridColumnsPort: NodeRowObserver
    @MainActor var spacingBetweenGridRowsPort: NodeRowObserver
    @MainActor var itemAlignmentWithinGridCellPort: NodeRowObserver
    
    @MainActor var widthAxisPort: NodeRowObserver
    @MainActor var heightAxisPort: NodeRowObserver
    @MainActor var contentModePort: NodeRowObserver
    @MainActor var minSizePort: NodeRowObserver
    @MainActor var maxSizePort: NodeRowObserver
    @MainActor var spacingPort: NodeRowObserver

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
        self.id = schema.id
        self.layer = schema.layer
        
        self.hasSidebarVisibility = schema.hasSidebarVisibility
        self.layerGroupId = schema.layerGroupId
        self.isExpandedInSidebar = schema.isExpandedInSidebar
        
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

        self.widthAxisPort = .empty(.widthAxis, layer: schema.layer)
        self.heightAxisPort = .empty(.heightAxis, layer: schema.layer)
        self.contentModePort = .empty(.contentMode, layer: schema.layer)
        self.minSizePort = .empty(.minSize, layer: schema.layer)
        self.maxSizePort = .empty(.maxSize, layer: schema.layer)
        self.spacingPort = .empty(.spacing, layer: schema.layer)
        
        let graphNode = schema.layer.layerGraphNode
        
        // Note: this should never actually be empty; only empty here as part of initialization; populated by a later call to `LayerNodeViewModel.didValuesUpdate`
        self.previewLayerViewModels = .init()
        
        // TODO: use the serialized data rather than default inputs which we override anyway
        // Initialize each NodeRowObserver for each expected layer input
        for inputType in graphNode.inputDefinitions {
            let id = NodeIOCoordinate(portType: .keyPath(inputType), nodeId: schema.id)
            let rowObserver = self[keyPath: inputType.layerNodeKeyPath]
            
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
            self[keyPath: $0.layerNodeKeyPath]
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
            schema[keyPath: inputType.schemaPortKeyPath] = self[keyPath: inputType.layerNodeKeyPath].createLayerSchema()
        }
        
        return schema
    }
    
    func onPrototypeRestart() { }
}

extension LayerNodeViewModel {
    @MainActor
    func getSortedInputObservers() -> NodeRowObservers {
        self.layer.layerGraphNode.inputDefinitions.map {
            self[keyPath: $0.layerNodeKeyPath]
        }
    }
    
    @MainActor
    func layerSize(_ activeIndex: ActiveIndex) -> LayerSize? {
        self.sizePort.getActiveValue(activeIndex: activeIndex).getSize
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
        self.positionPort.getActiveValue(activeIndex: activeIndex).getPoint
    }
    
    @MainActor
    func scaledLayerSize(for nodeId: NodeId,
                         parentSize: CGSize,
                         activeIndex: ActiveIndex) -> ScaledSize? {
        let scale = self.scalePort.getActiveValue(activeIndex: activeIndex).getNumber ?? .zero
        
        return self.sizePort.getActiveValue(activeIndex: activeIndex)
            .getSize?.asCGSize(parentSize)
            .asScaledSize(scale)
    }
}
