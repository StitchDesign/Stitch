//
//  LayerNode.swift
//  Stitch
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

    let layer: Layer

    // View models for layers in prototype window
    var previewLayerViewModels: [LayerViewModel] = [] 
 
    // Some layer nodes contain outputs
    var outputPorts: [OutputLayerNodeRowData] = []
    
    // Cached property to efficiently identify locations of input canvas nodes, if any created
    var _inputCanvasIds = Set<CanvasItemId>()
    
    // TODO: temporarily using positionPort as only canvas item location until inspector is done
    
    let positionPort: LayerInputObserver
    let sizePort: LayerInputObserver
    let scalePort: LayerInputObserver
    let anchoringPort: LayerInputObserver
    let opacityPort: LayerInputObserver
    let zIndexPort: LayerInputObserver
    let masksPort: LayerInputObserver
    let colorPort: LayerInputObserver
    let startColorPort: LayerInputObserver
    let endColorPort: LayerInputObserver
    let startAnchorPort: LayerInputObserver
    let endAnchorPort: LayerInputObserver
    let centerAnchorPort: LayerInputObserver
    let startAnglePort: LayerInputObserver
    let endAnglePort: LayerInputObserver
    let startRadiusPort: LayerInputObserver
    let endRadiusPort: LayerInputObserver
    let rotationXPort: LayerInputObserver
    let rotationYPort: LayerInputObserver
    let rotationZPort: LayerInputObserver
    let lineColorPort: LayerInputObserver
    let lineWidthPort: LayerInputObserver
    let blurPort: LayerInputObserver
    let blendModePort: LayerInputObserver
    let brightnessPort: LayerInputObserver
    let colorInvertPort: LayerInputObserver
    let contrastPort: LayerInputObserver
    let hueRotationPort: LayerInputObserver
    let saturationPort: LayerInputObserver
    let pivotPort: LayerInputObserver
    let enabledPort: LayerInputObserver
    let blurRadiusPort: LayerInputObserver
    let backgroundColorPort: LayerInputObserver
    let isClippedPort: LayerInputObserver
    let orientationPort: LayerInputObserver
    let paddingPort: LayerInputObserver
    let setupModePort: LayerInputObserver
    let allAnchorsPort: LayerInputObserver
    let cameraDirectionPort: LayerInputObserver
    let isCameraEnabledPort: LayerInputObserver
    let isShadowsEnabledPort: LayerInputObserver
    
    let shapePort: LayerInputObserver
    let strokePositionPort: LayerInputObserver
    let strokeWidthPort: LayerInputObserver
    let strokeColorPort: LayerInputObserver
    let strokeStartPort: LayerInputObserver
    let strokeEndPort: LayerInputObserver
    let strokeLineCapPort: LayerInputObserver
    let strokeLineJoinPort: LayerInputObserver
    let coordinateSystemPort: LayerInputObserver
    
    let cornerRadiusPort: LayerInputObserver
    let canvasLineColorPort: LayerInputObserver
    let canvasLineWidthPort: LayerInputObserver
    let textPort: LayerInputObserver
    let fontSizePort: LayerInputObserver
    let textAlignmentPort: LayerInputObserver
    let verticalAlignmentPort: LayerInputObserver
    let textDecorationPort: LayerInputObserver
    let textFontPort: LayerInputObserver
    let imagePort: LayerInputObserver
    let videoPort: LayerInputObserver
    let fitStylePort: LayerInputObserver
    let clippedPort: LayerInputObserver
    let isAnimatingPort: LayerInputObserver
    let progressIndicatorStylePort: LayerInputObserver
    let progressPort: LayerInputObserver
    let model3DPort: LayerInputObserver
    let mapTypePort: LayerInputObserver
    let mapLatLongPort: LayerInputObserver
    let mapSpanPort: LayerInputObserver
    let isSwitchToggledPort: LayerInputObserver
    let placeholderTextPort: LayerInputObserver
    
    let shadowColorPort: LayerInputObserver
    let shadowOpacityPort: LayerInputObserver
    let shadowRadiusPort: LayerInputObserver
    let shadowOffsetPort: LayerInputObserver
    let sfSymbolPort: LayerInputObserver
    
    let videoURLPort: LayerInputObserver
    let volumePort: LayerInputObserver
    
    let spacingBetweenGridColumnsPort: LayerInputObserver
    let spacingBetweenGridRowsPort: LayerInputObserver
    let itemAlignmentWithinGridCellPort: LayerInputObserver
    
    let widthAxisPort: LayerInputObserver
    let heightAxisPort: LayerInputObserver
    let contentModePort: LayerInputObserver
    let minSizePort: LayerInputObserver
    let maxSizePort: LayerInputObserver
    let spacingPort: LayerInputObserver
    let sizingScenarioPort: LayerInputObserver

    let isPinnedPort: LayerInputObserver
    let pinToPort: LayerInputObserver
    let pinAnchorPort: LayerInputObserver
    let pinOffsetPort: LayerInputObserver
    
    let layerMarginPort: LayerInputObserver
    let layerPaddingPort: LayerInputObserver
    let offsetInGroupPort: LayerInputObserver
    
    let materialThicknessPort: LayerInputObserver
    let deviceAppearancePort: LayerInputObserver
    
    @MainActor weak var nodeDelegate: NodeDelegate?

    // Sidebar visibility setting
    @MainActor var hasSidebarVisibility = true {
        didSet {
            dispatch(AssignedLayerUpdated(changedLayerNode: self.id.asLayerNodeId))
        }
    }

    @MainActor
    var layerGroupId: NodeId? {
        guard let graph = self.nodeDelegate?.graphDelegate else {
            log("LayerNodeViewModel: layerGroupId for layer \(self.id): no node or graph delegate?")
            return nil
        }
        
        guard let sidebarItem: SidebarItemGestureViewModel = graph.layersSidebarViewModel.items.get(self.id) else {
            log("LayerNodeViewModel: layerGroupId for layer \(self.id): no sidebar item")
            return nil
        }
        
        // log("LayerNodeViewModel: layerGroupId for layer \(self.id): sidebarItem.parentId: \(sidebarItem.parentId)")
        
        return sidebarItem.parentId
    }
    
    @MainActor
    init(from schema: LayerNodeEntity) {
        
        let graphNode = schema.layer.layerGraphNode
        
        // Create initial inputs and outputs using default data
        let rowDefinitions = NodeKind.layer(schema.layer)
            .rowDefinitions(for: nil)
        
        self.id = schema.id
        self.layer = schema.layer
        self.hasSidebarVisibility = schema.hasSidebarVisibility
                
        // TODO: remove `layerGroupId` from schema
        //self.layerGroupId = schema.layerGroupId
        
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
        
        self.deviceAppearancePort = .init(from: schema, port: .deviceAppearance)
        self.materialThicknessPort = .init(from: schema, port: .materialThickness)
        
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
    static func createObject(from entity: LayerNodeEntity,
                             activeIndex: ActiveIndex) -> Self {
        .init(from: entity)
    }

    func update(from schema: LayerNodeEntity) {
        assertInDebug(self.layer == schema.layer)
        
        if self.hasSidebarVisibility != schema.hasSidebarVisibility {
            self.hasSidebarVisibility = schema.hasSidebarVisibility
        }

        // TODO: remove `layerGroupId` from the `LayerNodeEntity`; now handled via sidebar item state
//        if self.layerGroupId != schema.layerGroupId {
//            self.layerGroupId = schema.layerGroupId
//        }
        
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
    
    /// Helper which discovers a layer node's inputs and passes its port into a callback.
    @MainActor
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
                                     layerGroupId: layerGroupId)
        
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
        
        // Reset known input canvas items
        self._inputCanvasIds = .init()
        
        // Set up outputs
        self.outputPorts.forEach {
            $0.initializeDelegate(node)
        }
        
        self.resetInputCanvasItemsCache()
    }
    
    @MainActor
    func resetInputCanvasItemsCache() {
        guard let node = self.nodeDelegate else {
            fatalErrorIfDebug()
            return
        }
        
        // Set up inputs
        self.forEachInput { layerInput in
            // Locate input canvas items for perf cache
            let inputCanvasItems = layerInput.getAllCanvasObservers()
                .map(\.id)
                .toSet
            self._inputCanvasIds = self._inputCanvasIds.union(inputCanvasItems)
            
            layerInput.initializeDelegate(node,
                                          layer: self.layer)
        }
        
        // Set blocked fields after all fields have been initialized
        self.forEachInput { layerInput in
            self.blockOrUnblockFields(
                newValue: layerInput.activeValue,
                layerInput: layerInput.port)
        }
    }
    
    @MainActor
    func getAllCanvasObservers() -> [CanvasItemViewModel] {
        // Use cache for inputs for perf
        let inputs: [CanvasItemViewModel] = self._inputCanvasIds.compactMap { canvasItemId -> CanvasItemViewModel? in
            guard let keyPath = canvasItemId.layerInputCase?.keyPath.layerNodeKeyPath else {
                fatalErrorIfDebug()
                return nil
            }
            
            return self[keyPath: keyPath].canvasObserver
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
