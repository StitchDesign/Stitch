//
//  LayerViewModel.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/12/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

/// "What is View A pinned to?"
//enum PinToId: Equatable, Hashable, Codable {
//    case root, // always preview window
//         parent, // immediate parent; defaults to preview window if pinned layer has no parent
//         layer(LayerNodeId)
//}

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

enum PinReceiverDataCase: Equatable, Hashable, Codable {
    case root(size: PinReceiverSizeData), // never has rotation data
         // either a parent or a different layer
         layer(size: PinReceiverSizeData,
               rotation: PinReceiverRotationData)
}

struct PinReceiverRotationData: Equatable, Hashable, Codable {
    // For determining PinnedView's rotation-anchor
    var center: CGPoint

    // PinReceiver's rotation is applied to the PinnedView
    var rotationX: CGFloat
    var rotationY: CGFloat
    var rotationZ: CGFloat
}

struct PinReceiverSizeData: Equatable, Hashable, Codable {
    // for anchoring
    var size: CGSize
    var origin: CGPoint // always 0,0 for
}

/// the data for "View B", which receives the pinned View A
struct PinReceiverData: Equatable {

//    let pinTo: PinToId

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

/// data for "View A", which is pinned to View B
struct PinnedData: Equatable {

    // size of the pinned view A, as affected by its parent;
    // for anchoring;
    // provided by the "GhostView"
    var size: CGSize

    // center of the (top level) PinnedView;
    // for rotation;
    // provided by the "PinnedView"
    var center: CGPoint
}

enum PinData: Equatable {
    case pinReceiver(PinReceiverData),
         pinned(PinnedData)
}

@Observable
final class LayerViewModel {
    var id: PreviewCoordinate
    let layer: Layer
    let interactiveLayer: InteractiveLayer
    weak var nodeDelegate: NodeDelegate?
    
    // PINNING

    // TODO: wrap these up into pinned- vs pinReceiving-data structures as seen above?

    // data for pin-receiving view, i.e. View B
    var pinReceiverSize: CGSize? = nil // anchor
    var pinReceiverOrigin: CGPoint? = nil // anchor
    var pinReceiverCenter: CGPoint? = nil // rotation

    // data for pinned view, i.e. View A
    var pinnedSize: CGSize? = nil // parent-affected size etc.; read by a "Ghost View" that sits in normal, expected place in hierarchy
    var pinnedCenter: CGPoint? = nil // not affected by parent's scale etc.; read by a "Pinned View" that sits at top of GeneratePreview
    
    // TODO: use `PortValue.sizingScenario` and retrieve from actual
//    var sizingScenario: SizingScenario = .constrainHeight
    
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
        
        self.position = LayerInputType.position.getDefaultValue(for: layer)
        self.size = LayerInputType.size.getDefaultValue(for: layer)
        self.scale = LayerInputType.scale.getDefaultValue(for: layer)
        self.anchoring = LayerInputType.anchoring.getDefaultValue(for: layer)
        self.startAnchor = LayerInputType.startAnchor.getDefaultValue(for: layer)
        self.endAnchor = LayerInputType.endAnchor.getDefaultValue(for: layer)
        self.centerAnchor = LayerInputType.centerAnchor.getDefaultValue(for: layer)
        self.startAngle = LayerInputType.startAngle.getDefaultValue(for: layer)
        self.endAngle = LayerInputType.endAngle.getDefaultValue(for: layer)
        self.startRadius = LayerInputType.startRadius.getDefaultValue(for: layer)
        self.endRadius = LayerInputType.endRadius.getDefaultValue(for: layer)
        self.opacity = LayerInputType.opacity.getDefaultValue(for: layer)
        self.zIndex = LayerInputType.zIndex.getDefaultValue(for: layer)
        self.masks = LayerInputType.masks.getDefaultValue(for: layer)
        self.color = LayerInputType.color.getDefaultValue(for: layer)
        self.startColor = LayerInputType.startColor.getDefaultValue(for: layer)
        self.endColor = LayerInputType.endColor.getDefaultValue(for: layer)
        self.rotationX = LayerInputType.rotationX.getDefaultValue(for: layer)
        self.rotationY = LayerInputType.rotationY.getDefaultValue(for: layer)
        self.rotationZ = LayerInputType.rotationZ.getDefaultValue(for: layer)
        self.lineColor = LayerInputType.lineColor.getDefaultValue(for: layer)
        self.lineWidth = LayerInputType.lineWidth.getDefaultValue(for: layer)
        self.blur = LayerInputType.blur.getDefaultValue(for: layer)
        self.blendMode = LayerInputType.blendMode.getDefaultValue(for: layer)
        self.brightness = LayerInputType.brightness.getDefaultValue(for: layer)
        self.colorInvert = LayerInputType.colorInvert.getDefaultValue(for: layer)
        self.contrast = LayerInputType.contrast.getDefaultValue(for: layer)
        self.hueRotation = LayerInputType.hueRotation.getDefaultValue(for: layer)
        self.saturation = LayerInputType.saturation.getDefaultValue(for: layer)
        self.pivot = LayerInputType.pivot.getDefaultValue(for: layer)
        self.enabled = LayerInputType.enabled.getDefaultValue(for: layer)
        self.blurRadius = LayerInputType.blurRadius.getDefaultValue(for: layer)
        self.backgroundColor = LayerInputType.backgroundColor.getDefaultValue(for: layer)
        self.isClipped = LayerInputType.isClipped.getDefaultValue(for: layer)
        self.orientation = LayerInputType.orientation.getDefaultValue(for: layer)
        self.padding = LayerInputType.padding.getDefaultValue(for: layer)
        self.setupMode = LayerInputType.setupMode.getDefaultValue(for: layer)
        self.allAnchors = [LayerInputType.allAnchors.getDefaultValue(for: layer)]
        self.cameraDirection = LayerInputType.cameraDirection.getDefaultValue(for: layer)
        self.isCameraEnabled = LayerInputType.isCameraEnabled.getDefaultValue(for: layer)
        self.isShadowsEnabled = LayerInputType.isShadowsEnabled.getDefaultValue(for: layer)
        
        self.shape = LayerInputType.shape.getDefaultValue(for: layer)
        self.strokePosition = LayerInputType.strokePosition.getDefaultValue(for: layer)
        self.strokeWidth = LayerInputType.strokeWidth.getDefaultValue(for: layer)
        self.strokeColor = LayerInputType.strokeColor.getDefaultValue(for: layer)
        self.strokeStart = LayerInputType.strokeStart.getDefaultValue(for: layer)
        self.strokeEnd = LayerInputType.strokeEnd.getDefaultValue(for: layer)
        self.strokeLineCap = LayerInputType.strokeLineCap.getDefaultValue(for: layer)
        self.strokeLineJoin = LayerInputType.strokeLineJoin.getDefaultValue(for: layer)
        self.coordinateSystem = LayerInputType.coordinateSystem.getDefaultValue(for: layer)
        
        self.cornerRadius = LayerInputType.cornerRadius.getDefaultValue(for: layer)
        self.canvasLineColor = LayerInputType.canvasLineColor.getDefaultValue(for: layer)
        self.canvasLineWidth = LayerInputType.canvasLineWidth.getDefaultValue(for: layer)
        self.text = LayerInputType.text.getDefaultValue(for: layer)
        self.fontSize = LayerInputType.fontSize.getDefaultValue(for: layer)
        self.textAlignment = LayerInputType.textAlignment.getDefaultValue(for: layer)
        self.verticalAlignment = LayerInputType.verticalAlignment.getDefaultValue(for: layer)
        self.textDecoration = LayerInputType.textDecoration.getDefaultValue(for: layer)
        self.textFont = LayerInputType.textFont.getDefaultValue(for: layer)
        self.image = LayerInputType.image.getDefaultValue(for: layer)
        self.video = LayerInputType.video.getDefaultValue(for: layer)
        self.fitStyle = LayerInputType.fitStyle.getDefaultValue(for: layer)
        self.clipped = LayerInputType.clipped.getDefaultValue(for: layer)
        self.isAnimating = LayerInputType.isAnimating.getDefaultValue(for: layer)
        self.progressIndicatorStyle = LayerInputType.progressIndicatorStyle.getDefaultValue(for: layer)
        self.progress = LayerInputType.progress.getDefaultValue(for: layer)
        self.model3D = LayerInputType.model3D.getDefaultValue(for: layer)
        self.mapType = LayerInputType.mapType.getDefaultValue(for: layer)
        self.mapLatLong = LayerInputType.mapLatLong.getDefaultValue(for: layer)
        self.mapSpan = LayerInputType.mapSpan.getDefaultValue(for: layer)
        self.isSwitchToggled = LayerInputType.isSwitchToggled.getDefaultValue(for: layer)
        self.placeholderText = LayerInputType.placeholderText.getDefaultValue(for: layer)
        
        self.shadowColor = LayerInputType.shadowColor.getDefaultValue(for: layer)
        self.shadowOpacity = LayerInputType.shadowOpacity.getDefaultValue(for: layer)
        self.shadowRadius = LayerInputType.shadowRadius.getDefaultValue(for: layer)
        self.shadowOffset = LayerInputType.shadowOffset.getDefaultValue(for: layer)
        self.sfSymbol = LayerInputType.sfSymbol.getDefaultValue(for: layer)
        self.videoURL = LayerInputType.videoURL.getDefaultValue(for: layer)
        self.volume = LayerInputType.volume.getDefaultValue(for: layer)
        
        self.spacingBetweenGridColumns = LayerInputType.spacingBetweenGridColumns.getDefaultValue(for: layer)
        
        self.spacingBetweenGridRows = LayerInputType.spacingBetweenGridRows.getDefaultValue(for: layer)
        
        self.itemAlignmentWithinGridCell = LayerInputType.itemAlignmentWithinGridCell.getDefaultValue(for: layer)

        self.widthAxis = LayerInputType.widthAxis.getDefaultValue(for: layer)
        self.heightAxis = LayerInputType.heightAxis.getDefaultValue(for: layer)
        self.contentMode = LayerInputType.contentMode.getDefaultValue(for: layer)
        self.minSize = LayerInputType.minSize.getDefaultValue(for: layer)
        self.maxSize = LayerInputType.maxSize.getDefaultValue(for: layer)
        self.spacing = LayerInputType.spacing.getDefaultValue(for: layer)
        
        self.sizingScenario = LayerInputType.sizingScenario.getDefaultValue(for: layer)
        
        self.isPinned = LayerInputType.isPinned.getDefaultValue(for: layer)
        self.pinTo = LayerInputType.pinTo.getDefaultValue(for: layer)
        self.pinAnchor = LayerInputType.pinAnchor.getDefaultValue(for: layer)
        self.pinOffset = LayerInputType.pinOffset.getDefaultValue(for: layer)
        
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
                                    inputType: LayerInputType) {
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
