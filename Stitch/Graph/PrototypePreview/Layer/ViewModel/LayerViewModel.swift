//
//  LayerViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import SwiftUI
import RealityKit
import StitchSchemaKit
import StitchEngine

@Observable
final class LayerViewModel: Sendable {
    private let mediaImportCoordinator = MediaLayerImportCoordinator()
    
    // Make unique ID for each layer view model so that a new creation can't use the same preview coordinate and confuse the view that nothing changed
    let _id = UUID()
    var id: PreviewCoordinate { self.previewCoordinate }
    let previewCoordinate: PreviewCoordinate
    let layer: Layer
    let interactiveLayer: InteractiveLayer
    
    @MainActor weak var nodeDelegate: NodeViewModel?
    
    // PINNING: "View A is pinned to View B"

    // TODO: wrap these up into pinned- vs pinReceiving-data structures as seen above?

    // data for pin-receiving view, i.e. View B
    @MainActor var pinReceiverSize: CGSize? = nil // anchor
    @MainActor var pinReceiverOrigin: CGPoint? = nil // anchor
    @MainActor var pinReceiverCenter: CGPoint? = nil // rotation

    // data for pinned view, i.e. View A
    @MainActor var pinnedSize: CGSize? = nil // parent-affected size (e.g. parent scaled 2x); read by a "Ghost View" that sits in view's normal, expected place in hierarchy.
    @MainActor var pinnedCenter: CGPoint? = nil // not affected by parent's scale, position etc.; read by a "Pinned View" that sits in same hierarchy level as the view it is pinned to.
    
    // Layer's frame as read by layer's background GeometryReader,
    // see `LayerSizeReader`.
    @MainActor
    var readFrame: CGRect = .zero {
        didSet {
            dispatch(AssignedLayerUpdated(changedLayerNode: self.previewCoordinate.layerNodeId))
        }
    }
    
    @MainActor var mediaViewModel = MediaViewModel()
    
    // State for media needed if we need to async load an import
    @MainActor var mediaObject: StitchMediaObject? {
        self.mediaViewModel.inputMedia?.mediaObject
    }
    
    @MainActor
    var mediaPortValue: AsyncMediaValue? {
        switch self.layer {
        case .video:
            return self.video.asyncMedia
        case .image:
            return self.image.asyncMedia
        case .model3D:
            return self.model3D.asyncMedia
        default:
            return nil
        }
    }
    
    // TODO: can we use specific types for the LayerViewModel? These types are always the same and known at compile-time (e.g. `position` is always a StitchPosition, `size` is always a LayerSize
    // Ports
    @MainActor var position: PortValue
    @MainActor var size: PortValue
    @MainActor var scale: PortValue
    @MainActor var anchoring: PortValue
    @MainActor var startAnchor: PortValue
    @MainActor var endAnchor: PortValue
    @MainActor var opacity: PortValue
    @MainActor var zIndex: PortValue
    @MainActor var masks: PortValue
    @MainActor var color: PortValue
    @MainActor var startColor: PortValue
    @MainActor var endColor: PortValue
    @MainActor var centerAnchor: PortValue
    @MainActor var startAngle: PortValue
    @MainActor var endAngle: PortValue
    @MainActor var startRadius: PortValue
    @MainActor var endRadius: PortValue
    @MainActor var rotationX: PortValue
    @MainActor var rotationY: PortValue
    @MainActor var rotationZ: PortValue
    @MainActor var lineColor: PortValue
    @MainActor var lineWidth: PortValue
    @MainActor var blur: PortValue
    @MainActor var blendMode: PortValue
    @MainActor var brightness: PortValue
    @MainActor var colorInvert: PortValue
    @MainActor var contrast: PortValue
    @MainActor var hueRotation: PortValue
    @MainActor var saturation: PortValue
    @MainActor var pivot: PortValue
    @MainActor var enabled: PortValue
    @MainActor var blurRadius: PortValue
    @MainActor var backgroundColor: PortValue
    @MainActor var isClipped: PortValue
    @MainActor var orientation: PortValue
    @MainActor var padding: PortValue
    @MainActor var setupMode: PortValue
    @MainActor var cameraDirection: PortValue
    @MainActor var isCameraEnabled: PortValue
    @MainActor var isShadowsEnabled: PortValue
    
    @MainActor var shape: PortValue
    @MainActor var strokePosition: PortValue
    @MainActor var strokeWidth: PortValue
    @MainActor var strokeColor: PortValue
    @MainActor var strokeStart: PortValue
    @MainActor var strokeEnd: PortValue
    @MainActor var strokeLineCap: PortValue
    @MainActor var strokeLineJoin: PortValue
    @MainActor var coordinateSystem: PortValue
    
    @MainActor var cornerRadius: PortValue
    @MainActor var canvasLineColor: PortValue
    @MainActor var canvasLineWidth: PortValue
    @MainActor var text: PortValue
    @MainActor var fontSize: PortValue
    @MainActor var textAlignment: PortValue
    @MainActor var verticalAlignment: PortValue
    @MainActor var textDecoration: PortValue
    @MainActor var textFont: PortValue
    @MainActor var beginEditing: PortValue
    @MainActor var endEditing: PortValue
    @MainActor var setText: PortValue
    @MainActor var textToSet: PortValue
    @MainActor var isSecureEntry: PortValue
    @MainActor var isSpellCheckEnabled: PortValue
    @MainActor var keyboardType: PortValue
    @MainActor var image: PortValue
    @MainActor var video: PortValue
    @MainActor var fitStyle: PortValue
    @MainActor var clipped: PortValue
    @MainActor var isAnimating: PortValue
    @MainActor var progressIndicatorStyle: PortValue
    @MainActor var progress: PortValue
    @MainActor var model3D: PortValue
    @MainActor var mapType: PortValue
    @MainActor var mapLatLong: PortValue
    @MainActor var mapSpan: PortValue
    @MainActor var isSwitchToggled: PortValue
    @MainActor var placeholderText: PortValue
    
    @MainActor var shadowColor: PortValue
    @MainActor var shadowOpacity: PortValue
    @MainActor var shadowRadius: PortValue
    @MainActor var shadowOffset: PortValue

    @MainActor var sfSymbol: PortValue
    
    @MainActor var videoURL: PortValue
    @MainActor var volume: PortValue
    
    @MainActor var spacingBetweenGridColumns: PortValue
    @MainActor var spacingBetweenGridRows: PortValue
    @MainActor var itemAlignmentWithinGridCell: PortValue

    @MainActor var sizingScenario: PortValue
    
    @MainActor var widthAxis: PortValue
    @MainActor var heightAxis: PortValue
    @MainActor var contentMode: PortValue
    
    // Min/max size
    @MainActor var minSize: PortValue
    @MainActor var maxSize: PortValue
    
    // Spacing
    @MainActor var spacing: PortValue

    // Pinning
    @MainActor var isPinned: PortValue
    @MainActor var pinTo: PortValue
    @MainActor var pinAnchor: PortValue
    @MainActor var pinOffset: PortValue
        
    @MainActor var layerPadding: PortValue
    @MainActor var layerMargin: PortValue
    @MainActor var offsetInGroup: PortValue
    @MainActor var layerGroupAlignment: PortValue

    // Material Layer
    @MainActor var materialThickness: PortValue
    @MainActor var deviceAppearance: PortValue
    
    // Scroll inputs
    @MainActor var scrollContentSize: PortValue
    @MainActor var isScrollAuto: PortValue
    @MainActor var scrollXEnabled: PortValue
    @MainActor var scrollJumpToXStyle: PortValue
    @MainActor var scrollJumpToX: PortValue
    @MainActor var scrollJumpToXLocation: PortValue
    @MainActor var scrollYEnabled: PortValue
    @MainActor var scrollJumpToYStyle: PortValue
    @MainActor var scrollJumpToY: PortValue
    @MainActor var scrollJumpToYLocation: PortValue
    
    // 3D
    @MainActor var transform3D: PortValue
    @MainActor var anchorEntity: PortValue
    @MainActor var isEntityAnimating: PortValue
    @MainActor var translation3DEnabled: PortValue
    @MainActor var rotation3DEnabled: PortValue
    @MainActor var scale3DEnabled: PortValue
    @MainActor var size3D: PortValue
    @MainActor var radius3D: PortValue
    @MainActor var height3D: PortValue
    @MainActor var isMetallic: PortValue
    
    // Ephemeral state on the layer view model
    
    @MainActor
    var ephemeralState: LayerEphemeralState = .init()
    
    // Canvas Sketch properties
    @MainActor var lines: DrawingViewLines {
        get {
            self.ephemeralState.lines
        } set(newValue) {
            self.ephemeralState.lines = newValue
        }
    }
    
    @MainActor var parentSizeFromDrag: CGSize {
        get {
            self.ephemeralState.parentSizeFromDrag
        } set(newValue) {
            self.ephemeralState.parentSizeFromDrag = newValue
        }
    }
    
    // Text Field property
    @MainActor var textFieldInput: String {
        get {
            self.ephemeralState.textFieldInput
        } set(newValue) {
            self.ephemeralState.textFieldInput = newValue
        }
    }
    
    // Switch Toggle property
    @MainActor var isUIToggled: Bool {
        get {
            self.ephemeralState.isUIToggled
        } set(newValue) {
            self.ephemeralState.isUIToggled = newValue
        }
    }
    
    // TODO: Why not initalize with proper values? If we need a 'default false/empty' LayerViewModel, do that view a separate function; and then pass in
    @MainActor
    init(id: PreviewCoordinate,
         layer: Layer,
         zIndex: PortValue = defaultNumber,
         position: PortValue = .position(.zero),
         nodeDelegate: NodeViewModel?) {
        
        self.previewCoordinate = id
        self.layer = layer
        self.zIndex = zIndex
        self.position = position
        self.interactiveLayer = .init(id: id)
        
        self.position = LayerInputPort.position.getDefaultValue(for: layer)
        self.size = LayerInputPort.size.getDefaultValue(for: layer)
        self.scale = LayerInputPort.scale.getDefaultValue(for: layer)
        self.anchoring = LayerInputPort.anchoring.getDefaultValue(for: layer)
        self.startAnchor = LayerInputPort.startAnchor.getDefaultValue(for: layer)
        self.endAnchor = LayerInputPort.endAnchor.getDefaultValue(for: layer)
        self.centerAnchor = LayerInputPort.centerAnchor.getDefaultValue(for: layer)
        self.startAngle = LayerInputPort.startAngle.getDefaultValue(for: layer)
        self.endAngle = LayerInputPort.endAngle.getDefaultValue(for: layer)
        self.startRadius = LayerInputPort.startRadius.getDefaultValue(for: layer)
        self.endRadius = LayerInputPort.endRadius.getDefaultValue(for: layer)
        self.opacity = LayerInputPort.opacity.getDefaultValue(for: layer)
        self.zIndex = LayerInputPort.zIndex.getDefaultValue(for: layer)
        self.masks = LayerInputPort.masks.getDefaultValue(for: layer)
        self.color = LayerInputPort.color.getDefaultValue(for: layer)
        self.startColor = LayerInputPort.startColor.getDefaultValue(for: layer)
        self.endColor = LayerInputPort.endColor.getDefaultValue(for: layer)
        self.rotationX = LayerInputPort.rotationX.getDefaultValue(for: layer)
        self.rotationY = LayerInputPort.rotationY.getDefaultValue(for: layer)
        self.rotationZ = LayerInputPort.rotationZ.getDefaultValue(for: layer)
        self.lineColor = LayerInputPort.lineColor.getDefaultValue(for: layer)
        self.lineWidth = LayerInputPort.lineWidth.getDefaultValue(for: layer)
        self.blur = LayerInputPort.blur.getDefaultValue(for: layer)
        self.blendMode = LayerInputPort.blendMode.getDefaultValue(for: layer)
        self.brightness = LayerInputPort.brightness.getDefaultValue(for: layer)
        self.colorInvert = LayerInputPort.colorInvert.getDefaultValue(for: layer)
        self.contrast = LayerInputPort.contrast.getDefaultValue(for: layer)
        self.hueRotation = LayerInputPort.hueRotation.getDefaultValue(for: layer)
        self.saturation = LayerInputPort.saturation.getDefaultValue(for: layer)
        self.pivot = LayerInputPort.pivot.getDefaultValue(for: layer)
        self.enabled = LayerInputPort.enabled.getDefaultValue(for: layer)
        self.blurRadius = LayerInputPort.blurRadius.getDefaultValue(for: layer)
        self.backgroundColor = LayerInputPort.backgroundColor.getDefaultValue(for: layer)
        self.isClipped = LayerInputPort.isClipped.getDefaultValue(for: layer)
        self.orientation = LayerInputPort.orientation.getDefaultValue(for: layer)
        self.padding = LayerInputPort.padding.getDefaultValue(for: layer)
        self.setupMode = LayerInputPort.setupMode.getDefaultValue(for: layer)
        self.cameraDirection = LayerInputPort.cameraDirection.getDefaultValue(for: layer)
        self.isCameraEnabled = LayerInputPort.isCameraEnabled.getDefaultValue(for: layer)
        self.isShadowsEnabled = LayerInputPort.isShadowsEnabled.getDefaultValue(for: layer)
        
        self.shape = LayerInputPort.shape.getDefaultValue(for: layer)
        self.strokePosition = LayerInputPort.strokePosition.getDefaultValue(for: layer)
        self.strokeWidth = LayerInputPort.strokeWidth.getDefaultValue(for: layer)
        self.strokeColor = LayerInputPort.strokeColor.getDefaultValue(for: layer)
        self.strokeStart = LayerInputPort.strokeStart.getDefaultValue(for: layer)
        self.strokeEnd = LayerInputPort.strokeEnd.getDefaultValue(for: layer)
        self.strokeLineCap = LayerInputPort.strokeLineCap.getDefaultValue(for: layer)
        self.strokeLineJoin = LayerInputPort.strokeLineJoin.getDefaultValue(for: layer)
        self.coordinateSystem = LayerInputPort.coordinateSystem.getDefaultValue(for: layer)
        
        self.cornerRadius = LayerInputPort.cornerRadius.getDefaultValue(for: layer)
        self.canvasLineColor = LayerInputPort.canvasLineColor.getDefaultValue(for: layer)
        self.canvasLineWidth = LayerInputPort.canvasLineWidth.getDefaultValue(for: layer)
        self.text = LayerInputPort.text.getDefaultValue(for: layer)
        self.fontSize = LayerInputPort.fontSize.getDefaultValue(for: layer)
        self.textAlignment = LayerInputPort.textAlignment.getDefaultValue(for: layer)
        self.verticalAlignment = LayerInputPort.verticalAlignment.getDefaultValue(for: layer)
        self.textDecoration = LayerInputPort.textDecoration.getDefaultValue(for: layer)
        self.textFont = LayerInputPort.textFont.getDefaultValue(for: layer)
        self.beginEditing = LayerInputPort.beginEditing.getDefaultValue(for: layer)
        self.endEditing = LayerInputPort.endEditing.getDefaultValue(for: layer)
        self.setText = LayerInputPort.setText.getDefaultValue(for: layer)
        self.textToSet = LayerInputPort.textToSet.getDefaultValue(for: layer)
        self.isSecureEntry = LayerInputPort.isSecureEntry.getDefaultValue(for: layer)
        self.isSpellCheckEnabled = LayerInputPort.isSpellCheckEnabled.getDefaultValue(for: layer)
        self.keyboardType = LayerInputPort.keyboardType.getDefaultValue(for: layer)
        self.image = LayerInputPort.image.getDefaultValue(for: layer)
        self.video = LayerInputPort.video.getDefaultValue(for: layer)
        self.fitStyle = LayerInputPort.fitStyle.getDefaultValue(for: layer)
        self.clipped = LayerInputPort.clipped.getDefaultValue(for: layer)
        self.isAnimating = LayerInputPort.isAnimating.getDefaultValue(for: layer)
        self.progressIndicatorStyle = LayerInputPort.progressIndicatorStyle.getDefaultValue(for: layer)
        self.progress = LayerInputPort.progress.getDefaultValue(for: layer)
        self.model3D = LayerInputPort.model3D.getDefaultValue(for: layer)
        self.mapType = LayerInputPort.mapType.getDefaultValue(for: layer)
        self.mapLatLong = LayerInputPort.mapLatLong.getDefaultValue(for: layer)
        self.mapSpan = LayerInputPort.mapSpan.getDefaultValue(for: layer)
        self.isSwitchToggled = LayerInputPort.isSwitchToggled.getDefaultValue(for: layer)
        self.placeholderText = LayerInputPort.placeholderText.getDefaultValue(for: layer)
        
        self.shadowColor = LayerInputPort.shadowColor.getDefaultValue(for: layer)
        self.shadowOpacity = LayerInputPort.shadowOpacity.getDefaultValue(for: layer)
        self.shadowRadius = LayerInputPort.shadowRadius.getDefaultValue(for: layer)
        self.shadowOffset = LayerInputPort.shadowOffset.getDefaultValue(for: layer)
        self.sfSymbol = LayerInputPort.sfSymbol.getDefaultValue(for: layer)
        self.videoURL = LayerInputPort.videoURL.getDefaultValue(for: layer)
        self.volume = LayerInputPort.volume.getDefaultValue(for: layer)
        
        self.spacingBetweenGridColumns = LayerInputPort.spacingBetweenGridColumns.getDefaultValue(for: layer)
        
        self.spacingBetweenGridRows = LayerInputPort.spacingBetweenGridRows.getDefaultValue(for: layer)
        
        self.itemAlignmentWithinGridCell = LayerInputPort.itemAlignmentWithinGridCell.getDefaultValue(for: layer)

        self.widthAxis = LayerInputPort.widthAxis.getDefaultValue(for: layer)
        self.heightAxis = LayerInputPort.heightAxis.getDefaultValue(for: layer)
        self.contentMode = LayerInputPort.contentMode.getDefaultValue(for: layer)
        self.minSize = LayerInputPort.minSize.getDefaultValue(for: layer)
        self.maxSize = LayerInputPort.maxSize.getDefaultValue(for: layer)
        self.spacing = LayerInputPort.spacing.getDefaultValue(for: layer)
        
        self.sizingScenario = LayerInputPort.sizingScenario.getDefaultValue(for: layer)
        
        self.isPinned = LayerInputPort.isPinned.getDefaultValue(for: layer)
        self.pinTo = LayerInputPort.pinTo.getDefaultValue(for: layer)
        self.pinAnchor = LayerInputPort.pinAnchor.getDefaultValue(for: layer)
        self.pinOffset = LayerInputPort.pinOffset.getDefaultValue(for: layer)
        self.layerPadding = LayerInputPort.layerPadding.getDefaultValue(for: layer)
        self.layerMargin = LayerInputPort.layerMargin.getDefaultValue(for: layer)
        self.offsetInGroup = LayerInputPort.offsetInGroup.getDefaultValue(for: layer)
        self.layerGroupAlignment = LayerInputPort.layerGroupAlignment.getDefaultValue(for: layer)
        
        self.materialThickness = LayerInputPort.materialThickness.getDefaultValue(for: layer)
        self.deviceAppearance = LayerInputPort.deviceAppearance.getDefaultValue(for: layer)
        
        self.scrollContentSize = LayerInputPort.scrollContentSize.getDefaultValue(for: layer)
        self.isScrollAuto = LayerInputPort.isScrollAuto.getDefaultValue(for: layer)
        self.scrollXEnabled = LayerInputPort.scrollXEnabled.getDefaultValue(for: layer)
        self.scrollJumpToXStyle = LayerInputPort.scrollJumpToXStyle.getDefaultValue(for: layer)
        self.scrollJumpToX = LayerInputPort.scrollJumpToX.getDefaultValue(for: layer)
        self.scrollJumpToXLocation = LayerInputPort.scrollJumpToXLocation.getDefaultValue(for: layer)
        self.scrollYEnabled = LayerInputPort.scrollYEnabled.getDefaultValue(for: layer)
        self.scrollJumpToYStyle = LayerInputPort.scrollJumpToYStyle.getDefaultValue(for: layer)
        self.scrollJumpToY = LayerInputPort.scrollJumpToY.getDefaultValue(for: layer)
        self.scrollJumpToYLocation = LayerInputPort.scrollJumpToYLocation.getDefaultValue(for: layer)
        
        self.transform3D = LayerInputPort.transform3D.getDefaultValue(for: layer)
        self.anchorEntity = LayerInputPort.anchorEntity.getDefaultValue(for: layer)
        self.isEntityAnimating = LayerInputPort.isEntityAnimating.getDefaultValue(for: layer)
        self.translation3DEnabled = LayerInputPort.translation3DEnabled.getDefaultValue(for: layer)
        self.rotation3DEnabled = LayerInputPort.rotation3DEnabled.getDefaultValue(for: layer)
        self.scale3DEnabled = LayerInputPort.scale3DEnabled.getDefaultValue(for: layer)
        self.size3D = LayerInputPort.size3D.getDefaultValue(for: layer)
        self.radius3D = LayerInputPort.radius3D.getDefaultValue(for: layer)
        self.height3D = LayerInputPort.height3D.getDefaultValue(for: layer)
        self.isMetallic = LayerInputPort.isMetallic.getDefaultValue(for: layer)
        
        self.nodeDelegate = nodeDelegate
        self.interactiveLayer.delegate = self
    }

    @MainActor
    convenience init(layerId: LayerNodeId,
                     loopIndex: Int,
                     layer: Layer,
                     nodeDelegate: NodeViewModel?) {
        let id = PreviewCoordinate(layerNodeId: layerId, loopIndex: loopIndex)
        self.init(id: id,
                  layer: layer,
                  nodeDelegate: nodeDelegate)
    }
}

extension LayerViewModel: InteractiveLayerDelegate {
    func getPosition() -> CGPoint {
        self.position.getPoint ?? .zero
    }
}

extension LayerViewModel {
    @MainActor var mediaRowObserver: InputNodeRowObserver? {
        guard let layerNode = self.nodeDelegate?.graphDelegate?
            .getNode(self.previewCoordinate.layerNodeId.asNodeId)?.layerNode else {
            return nil
        }
                
        switch layerNode.layer {
        case .image:
            assertInDebug(layerNode.imagePort.mode == .packed)
            return layerNode.imagePort.packedRowObserverOnlyIfPacked
        case .video:
            assertInDebug(layerNode.videoPort.mode == .packed)
            return layerNode.videoPort.packedRowObserverOnlyIfPacked
        case .model3D:
            assertInDebug(layerNode.model3DPort.mode == .packed)
            return layerNode.model3DPort.packedRowObserverOnlyIfPacked
        default:
            fatalErrorIfDebug()
            return nil
        }
    }
    
    func loadMedia(mediaValue: AsyncMediaValue?,
                   document: StitchDocumentViewModel,
                   mediaRowObserver: InputNodeRowObserver?) async {
        guard let mediaValue = mediaValue,
              let mediaKey = mediaValue.mediaKey else {
            // Covers media scenarios, ensuring we set to nil while task makes copy
            await MainActor.run { [weak self] in
                guard let viewModel = self else { return }
                
                Self.resetMedia(viewModel.mediaObject)
                
                // Only set media to nil if mediaValue is nil as well
                // Fixes issue where camrea feed would stutter
                if mediaValue == nil {
                    viewModel.mediaViewModel.inputMedia = nil
                }
            }
            return
        }
        
        guard let newMediaObject = await mediaImportCoordinator
            .getUniqueImport(mediaKey: mediaKey,
                             mediaValue: mediaValue,
                             document: document,
                             mediaRowObserver: mediaRowObserver) else {
            return
        }
        
        await MainActor.run { [weak self] in
            let mediaValue = GraphMediaValue(id: .init(),
                                             dataType: .source(mediaKey),
                                             mediaObject: newMediaObject)
            
            // Update parent layer node to override past upstream data
            self?.nodeDelegate?.layerNode?.mediaList = [mediaValue]
            
            // Update media here at this preview layer
            self?.mediaViewModel.inputMedia = mediaValue
        }
    }
    
    @MainActor
    func onPrototypeRestart(document: StitchDocumentViewModel) {
        // Rest interaction state values
        self.interactiveLayer.onPrototypeRestart(document: document)
        
        if let model3D = self.mediaObject?.model3DEntity,
           let transform = model3D.transform {
            model3D.applyMatrix(newMatrix: transform)
        }
        
        // Resets canvas sketch lines, text field input, toggle-state etc.
        self.ephemeralState = .init()
    }

    @MainActor
    static func resetMedia(_ mediaObject: StitchMediaObject?) {
        // Hack to remove video loop
        if let videoPlayer = mediaObject?.video {
            videoPlayer.pause()
            videoPlayer.stitchVideoDelegate.removeAllObservers()
        }
    }
    
    @MainActor
    var readSize: CGSize {
        self.readFrame.size
    }
    
    @MainActor
    var readMidPosition: CGPoint {
        self.readFrame.mid
    }
    
    @MainActor var isPinnedView: Bool {
        isPinned.getBool ?? false
    }
    
    @MainActor
    func updatePreviewLayer(from lengthenedValuesList: PortValuesList,
                            changedPortId: Int,
                            graph: GraphSetter) {
        guard let inputType = self.layer.layerGraphNode
            .inputDefinitions[safe: changedPortId] else {
            fatalErrorIfDebug()
            return
        }
        
        self.updatePreviewLayer(lengthenedValuesList: lengthenedValuesList,
                                portId: changedPortId,
                                inputType: inputType,
                                graph: graph)
    }
    
    /// Update preview layer from layer node.
    @MainActor
    private func updatePreviewLayer(lengthenedValuesList: PortValuesList,
                                    portId: Int,
                                    inputType: LayerInputPort,
                                    graph: GraphSetter) {
        let loopIndex = self.previewCoordinate.loopIndex
        let inputSupportsLoopedValues = inputType.supportsLoopedTypes
        
        if !inputSupportsLoopedValues {
            // Lengthen array for this loop to ensure there's a looped value
            guard let lengthenedValues = lengthenedValuesList[safe: portId] else {
                // log("LayerViewModel.createSortedInputs: unable to lengthen values for: \(valuesList)")
                // log("LayerViewModel.createSortedInputs: layer with id: \(layer) \(self.id.layerNodeId)")
                return
            }
            
            guard let value = lengthenedValues[safe: loopIndex] else {
                // log("LayerViewModel.createSortedInputs: unable to get looped value for lengthened values: \(lengthenedValues)\t loop index: \(loopIndex)")
                return
            }
            
            let oldValue = self.getValue(for: inputType)
            
            // Saves render cycles
            if oldValue != value {
                self.updatePreviewLayerInput(value, inputType: inputType)
                
                if inputType.shouldResortPreviewLayersIfChanged {
                    var graph = graph
                    graph.shouldResortPreviewLayers = true
                }
            }
        }
    }
    
    @MainActor
    func updateAllValues(with lengthenedValuesList: PortValuesList,
                         graph: GraphSetter) {
        let portIds = lengthenedValuesList.indices
        portIds.forEach {
            let portId = $0
            self.update(with: lengthenedValuesList,
                        changedPortId: portId,
                        graph: graph)
        }
    }

    @MainActor
    func update(with lengthenedValuesList: PortValuesList,
                changedPortId: Int,
                graph: GraphSetter) {
        self.updatePreviewLayer(from: lengthenedValuesList,
                                changedPortId: changedPortId,
                                graph: graph)
    }
}
