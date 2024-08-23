//
//  LayerViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension PinToId {
    static let defaultPinToId = Self.root

    var display: String {
        switch self {
        case .root:
            return LayerDropdownChoice.RootLayerDropDownChoice.name
        case .parent:
            return LayerDropdownChoice.ParentLayerDropDownChoice.name
        case .layer(let x):
            return x.id.description
        }
    }
}

struct PinReceiverSizeData: Equatable, Hashable, Codable {
    // for anchoring
    var size: CGSize
    var origin: CGPoint // always 0,0 for
}

/// the data for "View B", which receives the pinned View A
struct PinReceiverData: Equatable {

    // for anchoring
    var size: CGSize
    var origin: CGPoint // always 0,0 for

    // for rotation
    // Note: not applicable for PinTo.root, since PreviewWindow cannot be rotated
    var center: CGPoint

    // Note: for PinTo.root, will always be 0
    var rotationX: CGFloat
    var rotationY: CGFloat
    var rotationZ: CGFloat
}

@Observable
final class LayerViewModel {
    var id: PreviewCoordinate
    let layer: Layer
    let interactiveLayer: InteractiveLayer
    weak var nodeDelegate: NodeDelegate?
    
    // PINNING: "View A is pinned to View B"

    // TODO: wrap these up into pinned- vs pinReceiving-data structures as seen above?

    // data for pin-receiving view, i.e. View B
    var pinReceiverSize: CGSize? = nil // anchor
    var pinReceiverOrigin: CGPoint? = nil // anchor
    var pinReceiverCenter: CGPoint? = nil // rotation

    // data for pinned view, i.e. View A
    var pinnedSize: CGSize? = nil // parent-affected size (e.g. parent scaled 2x); read by a "Ghost View" that sits in view's normal, expected place in hierarchy.
    var pinnedCenter: CGPoint? = nil // not affected by parent's scale, position etc.; read by a "Pinned View" that sits in same hierarchy level as the view it is pinned to.
    
    // Size of the layer as read by layer's background GeometryReader,
    // see `LayerSizeReader`.
    var readSize: CGSize = .zero

    // Ports
    var position: PortValue
    var size: PortValue
    var scale: PortValue
    var anchoring: PortValue
    var startAnchor: PortValue
    var endAnchor: PortValue
    var opacity: PortValue
    var zIndex: PortValue
    var masks: PortValue
    var color: PortValue
    var startColor: PortValue
    var endColor: PortValue
    var centerAnchor: PortValue
    var startAngle: PortValue
    var endAngle: PortValue
    var startRadius: PortValue
    var endRadius: PortValue
    var rotationX: PortValue
    var rotationY: PortValue
    var rotationZ: PortValue
    var lineColor: PortValue
    var lineWidth: PortValue
    var blur: PortValue
    var blendMode: PortValue
    var brightness: PortValue
    var colorInvert: PortValue
    var contrast: PortValue
    var hueRotation: PortValue
    var saturation: PortValue
    var pivot: PortValue
    var enabled: PortValue
    var blurRadius: PortValue
    var backgroundColor: PortValue
    var isClipped: PortValue
    var orientation: PortValue
    var padding: PortValue
    var setupMode: PortValue
    var allAnchors: PortValues
    var cameraDirection: PortValue
    var isCameraEnabled: PortValue
    var isShadowsEnabled: PortValue
    
    var shape: PortValue
    var strokePosition: PortValue
    var strokeWidth: PortValue
    var strokeColor: PortValue
    var strokeStart: PortValue
    var strokeEnd: PortValue
    var strokeLineCap: PortValue
    var strokeLineJoin: PortValue
    var coordinateSystem: PortValue
    
    var cornerRadius: PortValue
    var canvasLineColor: PortValue
    var canvasLineWidth: PortValue
    var text: PortValue
    var fontSize: PortValue
    var textAlignment: PortValue
    var verticalAlignment: PortValue
    var textDecoration: PortValue
    var textFont: PortValue
    var image: PortValue
    var video: PortValue
    var fitStyle: PortValue
    var clipped: PortValue
    var isAnimating: PortValue
    var progressIndicatorStyle: PortValue
    var progress: PortValue
    var model3D: PortValue
    var mapType: PortValue
    var mapLatLong: PortValue
    var mapSpan: PortValue
    var isSwitchToggled: PortValue
    var placeholderText: PortValue
    
    var shadowColor: PortValue
    var shadowOpacity: PortValue
    var shadowRadius: PortValue
    var shadowOffset: PortValue

    var sfSymbol: PortValue
    
    var videoURL: PortValue
    var volume: PortValue
    
    var spacingBetweenGridColumns: PortValue
    var spacingBetweenGridRows: PortValue
    var itemAlignmentWithinGridCell: PortValue

    var sizingScenario: PortValue
    
    var widthAxis: PortValue
    var heightAxis: PortValue
    var contentMode: PortValue
    
    // Min/max size
    var minSize: PortValue
    var maxSize: PortValue
    
    // Spacing
    var spacing: PortValue

    // Pinning
    var isPinned: PortValue
    var pinTo: PortValue
    var pinAnchor: PortValue
    var pinOffset: PortValue
    
    // TODO: source these from LayerNodeViewModel after SSK update
    var layerPadding: StitchPadding = .zero // .demoPadding // PortValue
    var layerMargin: StitchPadding = .zero // .demoPadding // PortValue
    var offsetInGroup: CGSize = .zero // .init(width: 50, height: 100)
    
    // Ephemeral state on the layer view model
    
    // Canvas Sketch properties
    var lines: DrawingViewLines = .init()
    var parentSizeFromDrag: CGSize = .zero
    
    // Text Field property
    var textFieldInput: String = ""
    
    // Switch Toggle property
    var isUIToggled: Bool = false
    
    init(id: PreviewCoordinate,
         layer: Layer,
         zIndex: PortValue = defaultNumber,
         position: PortValue = .position(.zero),
         nodeDelegate: NodeDelegate?) {
        self.id = id
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
        self.allAnchors = [LayerInputPort.allAnchors.getDefaultValue(for: layer)]
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
        
        self.nodeDelegate = nodeDelegate
        self.interactiveLayer.delegate = self
    }

    convenience init(layerId: LayerNodeId,
                     loopIndex: Int,
                     layer: Layer,
                     nodeDelegate: NodeDelegate?) {
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
    @MainActor
    func updatePreviewLayer(from lengthenedValuesList: PortValuesList,
                            changedPortId: Int) {
        guard let inputType = self.layer.layerGraphNode
            .inputDefinitions[safe: changedPortId] else {
            fatalErrorIfDebug()
            return
        }
        
        self.updatePreviewLayer(lengthenedValuesList: lengthenedValuesList,
                                portId: changedPortId,
                                inputType: inputType)
    }
    
    /// Update preview layer from layer node.
    @MainActor
    private func updatePreviewLayer(lengthenedValuesList: PortValuesList,
                                    portId: Int,
                                    inputType: LayerInputPort) {
        let loopIndex = self.id.loopIndex
        let inputSupportsLoopedValues = inputType.supportsLoopedTypes
        
        if !inputSupportsLoopedValues {
            // Lengthen array for this loop to ensure there's a looped value
            guard let lengthenedValues = lengthenedValuesList[safe: portId] else {
#if DEV_DEBUG
                //                log("LayerViewModel.createSortedInputs: unable to lengthen values for: \(valuesList)")
                //                    log("LayerViewModel.createSortedInputs: layer with id: \(layer) \(self.id.layerNodeId)")
#endif
                return
            }
            
            guard let value = lengthenedValues[safe: loopIndex] else {
#if DEV_DEBUG
                log("LayerViewModel.createSortedInputs: unable to get looped value for lengthened values: \(lengthenedValues)\t loop index: \(loopIndex)")
#endif
                return
            }
            
            let oldValue = self.getValue(for: inputType)
            
            // Saves render cycles
            if oldValue != value {
                self.updatePreviewLayerInput(value, inputType: inputType)
                
                if inputType.shouldResetGraphPreviews {
                    self.nodeDelegate?.graphDelegate?.shouldResortPreviewLayers = true
                }
            }
        }
        
        // Multi-value key paths (all anchors in reality node)
        else {
            // No looping index used for multi-value key path
            if let values = lengthenedValuesList[safe: portId] {
                let oldValues = self.getValues(for: inputType)
                
                // Saves render cycles
                if oldValues != values {
                    self.updatePreviewLayerInput(values, inputType: inputType)
                    
                    if inputType.shouldResetGraphPreviews {
                        self.nodeDelegate?.graphDelegate?.shouldResortPreviewLayers = true
                    }
                }
            }
        }
    }
    
    @MainActor
    func updateAllValues(with lengthenedValuesList: PortValuesList) {
        let portIds = lengthenedValuesList.indices
        portIds.forEach {
            let portId = $0
            self.update(with: lengthenedValuesList,
                        changedPortId: portId)
        }
    }

    @MainActor
    func update(with lengthenedValuesList: PortValuesList,
                changedPortId: Int) {
        self.updatePreviewLayer(from: lengthenedValuesList,
                                changedPortId: changedPortId)
    }
}
