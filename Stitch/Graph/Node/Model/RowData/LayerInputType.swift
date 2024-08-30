//
//  LayerInputType.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 4/4/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

extension CGFloat {
    static let DEFAULT_FONT_SIZE = 36.0
}

extension LayerDimension {
    static let DEFAULT_FONT_SIZE = Self.number(.DEFAULT_FONT_SIZE)
}

extension LayerInputType {
    func getDefaultValue(for layer: Layer) -> PortValue {
        let defaultPackedValue = self.layerInput.getDefaultValue(for: layer)
        
        switch self.portType {
        case .packed:
            return defaultPackedValue
                    
        case .unpacked(let unpackedType):
            if !FeatureFlags.SUPPORTS_LAYER_UNPACK {
                // TODO: ignore packing logic below for until feature is supported
                return .none
            }
            
            guard let unpackedValues = self.layerInput.unpackValues(from: defaultPackedValue) else {
                if FeatureFlags.SUPPORTS_LAYER_UNPACK {
                    // TODO: unpackValues caller needs to be fixed when removing feature flag
//                    fatalErrorIfDebug("Unpacking shouldn't have been called for port: \(self.layerInput)")
                }
                
                return .none
            }
            
            guard let valueAtPort = unpackedValues[safe: unpackedType.rawValue] else {
                // Hit for .empty callers
//                fatalErrorIfDebug()
                return unpackedValues.first ?? .none
            }
            
            return valueAtPort
        }
    }
}

extension LayerInputPort {
    func getDefaultValue(for layer: Layer) -> PortValue {
        switch self {
            // Required everywhere
        case .position:
            return .position(.zero)
        case .size:
            switch layer {
            case .image, .video, .realityView:
                return .size(defaultImageSize)
            case .canvasSketch:
                return .size(LayerSize.CANVAS_LAYER_DEFAULT_SIZE)
            case .map:
                return .size(LayerSize.DEFAULT_MAP_SIZE)
            case .videoStreaming:
                return .size(LayerSize.DEFAULT_VIDEO_STREAMING_SIZE)
            case .textField:
                return .size(LayerSize.DEFAULT_TEXT_FIELD_SIZE)
            case .text:
                return .size(LayerSize.DEFAULT_TEXT_LABEL_SIZE)
            case .group:
                return .size(.init(width: .hug, height: .hug))
            default:
                return .size(.LAYER_DEFAULT_SIZE)
            }
        case .scale:
            return .number(1)
        case .anchoring:
            return .anchoring(.defaultAnchoring)
        case .opacity:
            return defaultOpacity
        case .zIndex:
            return .number(.zero)
        case .masks:
            return .bool(false)
        case .color:
            return .color(initialLayerColor())
        case .rotationX:
            return .number(.zero)
        case .rotationY:
            return .number(.zero)
        case .rotationZ:
            return .number(.zero)
        case .lineColor:
            return .color(CanvasSketchLayerNodeHelpers.defaultLineColor)
        case .lineWidth:
            return .number(CanvasSketchLayerNodeHelpers.defaultLineWidth)
        case .blur:
            return .number(0)
        case .blendMode:
            return .blendMode(.defaultBlendMode)
        case .brightness:
            return .number(.defaultBrightnessForLayerEffect)
        case .colorInvert:
            return .bool(.defaultColorInvertForLayerEffect)
        case .contrast:
            return .number(.defaultContrastForLayerEffect)
        case .hueRotation:
            return .number(.defaultHueRotationForLayerEffect)
        case .saturation:
            return .number(.defaultSaturationForLayerEffect)
        case .pivot:
            return .anchoring(.centerCenter)
        case .enabled:
            return .bool(true)
        case .blurRadius:
            return .number(.zero)
        case .backgroundColor:
            return .color(DEFAULT_GROUP_BACKGROUND_COLOR)
        case .isClipped:
            return .bool(true)
        case .orientation:
            return .orientation(.none)
        case .padding:
            return .padding(.defaultPadding)
        case .setupMode:
            return .bool(true)
        case .allAnchors:
            return .asyncMedia(nil)
        case .cameraDirection:
            return .cameraDirection(.back)
        case .isCameraEnabled:
            return .bool(true)
        case .isShadowsEnabled:
            return .bool(true)
        
        case.shape:
            return .shape(nil)
        case .strokePosition:
            return .layerStroke(.defaultStroke)
        case .strokeWidth:
            return .number(4)
        case .strokeColor:
            return .color(falseColor)
        case .strokeStart:
            return .number(.zero)
        case .strokeEnd:
            return .number(1.0)
        case .strokeLineCap:
            return .strokeLineCap(.defaultStrokeLineCap)
        case .strokeLineJoin:
            return .strokeLineJoin(.defaultStrokeLineJoin)
            
        case .coordinateSystem:
            return .shapeCoordinates(.relative)
        case .canvasLineColor:
            return .color(CanvasSketchLayerNodeHelpers.defaultLineColor)
        case .canvasLineWidth:
            return .number(CanvasSketchLayerNodeHelpers.defaultLineWidth)
        case .cornerRadius:
            return .number(.zero)
        case .text:
            return .string(.init(DEFAULT_TEXT_VALUE))
        case .fontSize:
            return .layerDimension(.number(.DEFAULT_FONT_SIZE))
        case .textAlignment:
            return .textAlignment(DEFAULT_TEXT_ALIGNMENT)
        case .verticalAlignment:
            return .textVerticalAlignment(DEFAULT_TEXT_VERTICAL_ALIGNMENT)
        case .textDecoration:
            return .textDecoration(.defaultLayerTextDecoration)
        case .textFont:
            return .textFont(.defaultStitchFont)
        case .image, .video, .model3D:
            return .asyncMedia(nil)
        case .fitStyle:
            return .fitStyle(.fill)
        case .clipped:
            return .bool(true)
        case .mapType:
            return .mapType(.defaultMapType)
        case .mapLatLong:
            return .position(DEFAULT_MAP_LAT_LONG_POSITION)
        case .mapSpan:
            return .position(DEFAULT_MAP_LAT_LONG_SPAN)
        case .isSwitchToggled:
            return pulseDefaultFalse
        case .isAnimating:
            return .bool(true)
        case .progressIndicatorStyle:
            return .progressIndicatorStyle(.circular)
        case .progress:
            return .number(DEFAULT_PROGRESS_VALUE)
        case .placeholderText:
            return .string(.init(DEFAULT_TEXT_PLACEHOLDER_VALUE))
        case .startColor:
            return .color(DEFAULT_GRADIENT_START_COLOR)
        case .endColor:
            return .color(DEFAULT_GRADIENT_END_COLOR)
        case .startAnchor:
            return .anchoring(.topCenter)
        case .endAnchor:
            return .anchoring(.bottomCenter)
        case .centerAnchor:
            return .anchoring(.centerCenter)
        case .startAngle:
            return .number(1)
        case .endAngle:
            return .number(100)
        case .startRadius:
            return .number(1)
        case .endRadius:
            return .number(100)
        case .shadowColor:
            return .color(.defaultShadowColor)
        case .shadowOpacity:
            return .number(.defaultShadowOpacity)
        case .shadowRadius:
            return .number(.defaultShadowRadius)
        case .shadowOffset:
            return .position(.defaultShadowOffset)
        case .sfSymbol:
            return .string(.init(DEFAULT_SF_SYMBOL))
        case .volume:
            return .number(DEFAULT_VIDEO_VOLUME)
        case .videoURL:
            return .string(.init(""))
        case .spacingBetweenGridColumns:
            return .number(.zero)
        case .spacingBetweenGridRows:
            return .number(.zero)
        case .itemAlignmentWithinGridCell:
            return .anchoring(.centerCenter)
        case .widthAxis:
            return .number(1)
        case .heightAxis:
            return .number(1)
        case .contentMode:
            return .contentMode(.defaultContentMode)
        case .minSize:
            return .size(.init(width: .auto, height: .auto))
        case .maxSize:
            return .size(.init(width: .auto, height: .auto))
        case .spacing:
            return .spacing(.defaultStitchSpacing)
        case .sizingScenario:
            return .sizingScenario(.auto)
        case .isPinned:
            return .bool(false)
        case .pinTo:
            return .pinTo(.defaultPinToId)
        case .pinAnchor:
            return .anchoring(.defaultAnchoring)
        case .pinOffset:
            return .size(.zero)
        case .layerPadding:
            return .padding(.zero)
        case .layerMargin:
            return .padding(.zero)
        case .offsetInGroup:
            return .size(.zero)
        }
    }
    
    /// Keypath mapping to this schema version.
    var schemaPortKeyPath: WritableKeyPath<LayerNodeEntity, LayerInputEntity> {
        switch self {
            
        // Required
        case .position:
            return \.positionPort
        case .size:
            return \.sizePort
        case .scale:
            return \.scalePort
        case .anchoring:
            return \.anchoringPort
        case .opacity:
            return \.opacityPort
        case .zIndex:
            return \.zIndexPort
        
        // Common
        case .masks:
            return \.masksPort
        case .color:
            return \.colorPort
        case .rotationX:
            return \.rotationXPort
        case .rotationY:
            return \.rotationYPort
        case .rotationZ:
            return \.rotationZPort
        case .lineColor:
            return \.lineColorPort
        case .lineWidth:
            return \.lineWidthPort
        case .blur:
            return \.blurPort
        case .blendMode:
            return \.blendModePort
        case .brightness:
            return \.brightnessPort
        case .colorInvert:
            return \.colorInvertPort
        case .contrast:
            return \.contrastPort
        case .hueRotation:
            return \.hueRotationPort
        case .saturation:
            return \.saturationPort
        case .pivot:
            return \.pivotPort
        case .enabled:
            return \.enabledPort
        case .blurRadius:
            return \.blurRadiusPort
        case .backgroundColor:
            return \.backgroundColorPort
        case .isClipped:
            return \.isClippedPort
        case .orientation:
            return \.orientationPort
        case .padding:
            return \.paddingPort
        case .setupMode:
            return \.setupModePort
        case .allAnchors:
            return \.allAnchorsPort
        case .cameraDirection:
            return \.cameraDirectionPort
        case .isCameraEnabled:
            return \.isCameraEnabledPort
        case .isShadowsEnabled:
            return \.isShadowsEnabledPort
        
        case .shape:
            return \.shapePort
        case .strokePosition:
            return \.strokePositionPort
        case .strokeWidth:
            return \.strokeWidthPort
        case .strokeColor:
            return \.strokeColorPort
        case .strokeStart:
            return \.strokeStartPort
        case .strokeEnd:
            return \.strokeEndPort
        case .strokeLineCap:
            return \.strokeLineCapPort
        case .strokeLineJoin:
            return \.strokeLineJoinPort
        case .coordinateSystem:
            return \.coordinateSystemPort
        case .cornerRadius:
            return \.cornerRadiusPort
        
        case .canvasLineColor:
            return \.canvasLineColorPort
        case .canvasLineWidth:
            return \.canvasLineWidthPort
        case .text:
            return \.textPort
        case .fontSize:
            return \.fontSizePort
        case .textAlignment:
            return \.textAlignmentPort
        case .verticalAlignment:
            return \.verticalAlignmentPort
        case .textDecoration:
            return \.textDecorationPort
        case .textFont:
            return \.textFontPort
        case .image:
            return \.imagePort
        case .video:
            return \.videoPort
        case .fitStyle:
            return \.fitStylePort
        case .clipped:
            return \.clippedPort
        case .isAnimating:
            return \.isAnimatingPort
        case .progressIndicatorStyle:
            return \.progressIndicatorStylePort
        case .progress:
            return \.progressPort
        case .model3D:
            return \.model3DPort
        case .mapType:
            return \.mapTypePort
        case .mapLatLong:
            return \.mapLatLongPort
        case .mapSpan:
            return \.mapSpanPort
        case .isSwitchToggled:
            return \.isSwitchToggledPort
        case .placeholderText:
            return \.placeholderTextPort
        case .startColor:
            return \.startColorPort
        case .endColor:
            return \.endColorPort
        case .startAnchor:
            return \.startAnchorPort
        case .endAnchor:
            return \.endAnchorPort
        case .centerAnchor:
            return \.centerAnchorPort
        case .startAngle:
            return \.startAnglePort
        case .endAngle:
            return \.endAnglePort
        case .startRadius:
            return \.startRadiusPort
        case .endRadius:
            return \.endRadiusPort
        
        case .shadowColor:
            return \.shadowColorPort
        case .shadowOpacity:
            return \.shadowOpacityPort
        case .shadowRadius:
            return \.shadowRadiusPort
        case .shadowOffset:
            return \.shadowOffsetPort
        case .sfSymbol:
            return \.sfSymbolPort
            
        case .videoURL:
            return \.videoURLPort
        case .volume:
            return \.volumePort
            
        case .spacingBetweenGridColumns:
            return \.spacingBetweenGridColumnsPort
        case .spacingBetweenGridRows:
            return \.spacingBetweenGridRowsPort
        case .itemAlignmentWithinGridCell:
            return \.itemAlignmentWithinGridCellPort
        
        case .widthAxis:
            return \.widthAxisPort
        case .heightAxis:
            return \.heightAxisPort
        case .contentMode:
            return \.contentModePort
  
        case .minSize:
            return \.minSizePort
        case .maxSize:
            return \.maxSizePort
        
        case .spacing:
            return \.spacingPort
            
        case .sizingScenario:
            return \.sizingScenarioPort
            
        case .isPinned:
            return \.isPinnedPort
        case .pinTo:
            return \.pinToPort
        case .pinAnchor:
            return \.pinAnchorPort
        case .pinOffset:
            return \.pinOffsetPort
        case .layerPadding:
            return \.layerPaddingPort
        case .layerMargin:
            return \.layerMarginPort
        case .offsetInGroup:
            return \.offsetInGroupPort
        }
    }
    
    var supportsLoopedTypes: Bool {
        switch self {
        case .allAnchors:
            return true
            
        default:
            return false
        }
    }
}

extension LayerViewModel {
    func getValues(for inputType: LayerInputPort) -> PortValues {
        assertInDebug(inputType.supportsLoopedTypes)
        
        switch inputType {
        case .allAnchors:
            return self.allAnchors
            
        default:
            fatalErrorIfDebug()
            return [.number(.zero)]
        }
    }
    
    /// Updates inputs that accept an array of values.
    func updatePreviewLayerInput(_ values: PortValues,
                                 inputType: LayerInputPort) {
        assertInDebug(inputType.supportsLoopedTypes)
        
        switch inputType {
        case .allAnchors:
            self.allAnchors = values
        default:
            fatalErrorIfDebug()
        }
    }
    
    /// Key paths for children preview layers.
    func getValue(for inputType: LayerInputPort) -> PortValue {
        switch inputType {
            // MARK: not supported here
        case .allAnchors:
            fatalErrorIfDebug()
            return .number(.zero)
            
            // Required for all layers
        case .position:
            return self.position
        case .size:
            return self.size
        case .scale:
            return self.scale
        case .anchoring:
            return self.anchoring
        case .opacity:
            return self.opacity
        case .zIndex:
            return self.zIndex
            
            // Common to many layers
        case .masks:
            return self.masks
        case .color:
            return self.color
        case .rotationX:
            return self.rotationX
        case .rotationY:
            return self.rotationY
        case .rotationZ:
            return self.rotationZ
        case .lineColor:
            return self.lineColor
        case .lineWidth:
            return self.lineWidth
        case .blur:
            return self.blur
        case .blendMode:
            return self.blendMode
        case .brightness:
            return self.brightness
        case .colorInvert:
            return self.colorInvert
        case .contrast:
            return self.contrast
        case .hueRotation:
            return self.hueRotation
        case .saturation:
            return self.saturation
        case .pivot:
            return self.pivot
        case .enabled:
            return self.enabled
        case .blurRadius:
            return self.blurRadius
        case .backgroundColor:
            return self.backgroundColor
        case .isClipped:
            return self.isClipped
        case .orientation:
            return self.orientation
        case .padding:
            return self.padding
        case .setupMode:
            return self.setupMode
        case .cameraDirection:
            return self.cameraDirection
        case .isCameraEnabled:
            return self.isCameraEnabled
        case .isShadowsEnabled:
            return self.isShadowsEnabled
            
        case .shape:
            return self.shape
            
        case .strokePosition:
            return self.strokePosition
        case .strokeWidth:
            return self.strokeWidth
        case .strokeColor:
            return self.strokeColor
        case .strokeStart:
            return self.strokeStart
        case .strokeEnd:
            return self.strokeEnd
        case .strokeLineCap:
            return self.strokeLineCap
        case .strokeLineJoin:
            return self.strokeLineJoin
            
        case .coordinateSystem:
            return self.coordinateSystem
        case .cornerRadius:
            return self.cornerRadius
        case .canvasLineColor:
            return self.canvasLineColor
        case .canvasLineWidth:
            return self.canvasLineWidth
        case .text:
            return self.text
        case .fontSize:
            return self.fontSize
        case .textAlignment:
            return self.textAlignment
        case .verticalAlignment:
            return self.verticalAlignment
        case .textDecoration:
            return self.textDecoration
        case .textFont:
            return self.textFont
        case .image:
            return self.image
        case .video:
            return self.video
        case .fitStyle:
            return self.fitStyle
        case .clipped:
            return self.clipped
        case .isAnimating:
            return self.isAnimating
        case .progressIndicatorStyle:
            return self.progressIndicatorStyle
        case .progress:
            return self.progress
        case .model3D:
            return self.model3D
        case .mapType:
            return self.mapType
        case .mapLatLong:
            return self.mapLatLong
        case .mapSpan:
            return self.mapSpan
        case .isSwitchToggled:
            return self.isSwitchToggled
        case .placeholderText:
            return self.placeholderText
        case .startColor:
            return self.startColor
        case .endColor:
            return self.endColor
        case .startAnchor:
            return self.startColor
        case .endAnchor:
            return self.endAnchor
        case .centerAnchor:
            return self.centerAnchor
        case .startAngle:
            return self.startAngle
        case .endAngle:
            return self.endAngle
        case .startRadius:
            return self.startRadius
        case .endRadius:
            return self.endRadius
        case .shadowColor:
            return self.shadowColor
        case .shadowOpacity:
            return self.shadowOpacity
        case .shadowRadius:
            return self.shadowRadius
        case .shadowOffset:
            return self.shadowOffset
        case .sfSymbol:
            return self.sfSymbol
        case .videoURL:
            return self.videoURL
        case .volume:
            return self.volume
        case .spacingBetweenGridColumns:
            return self.spacingBetweenGridColumns
        case .spacingBetweenGridRows:
            return self.spacingBetweenGridRows
        case .itemAlignmentWithinGridCell:
            return self.itemAlignmentWithinGridCell
        case .widthAxis:
            return self.widthAxis
        case .heightAxis:
            return self.heightAxis
        case .contentMode:
            return self.contentMode
        case .minSize:
            return self.minSize
        case .maxSize:
            return self.maxSize
        case .spacing:
            return self.spacing
        case .sizingScenario:
            return self.sizingScenario
        case .isPinned:
            return self.isPinned
        case .pinTo:
            return self.pinTo
        case .pinAnchor:
            return self.pinAnchor
        case .pinOffset:
            return self.pinOffset
        case .layerPadding:
            return self.layerPadding
        case .layerMargin:
            return self.layerMargin
        case .offsetInGroup:
            return self.offsetInGroup
        }
    }
    
    /// Key paths for children preview layers.
    func updatePreviewLayerInput(_ value: PortValue,
                                 inputType: LayerInputPort) {
        switch inputType {
            // MARK: not supported here
        case .allAnchors:
            fatalErrorIfDebug()
            
            // Required for all layers
        case .position:
            self.position = value
        case .size:
            self.size = value
        case .scale:
            self.scale = value
        case .anchoring:
            self.anchoring = value
        case .opacity:
            self.opacity = value
        case .zIndex:
            self.zIndex = value
            
            // Common to many layers
        case .masks:
            self.masks = value
        case .color:
            self.color = value
        case .rotationX:
            self.rotationX = value
        case .rotationY:
            self.rotationY = value
        case .rotationZ:
            self.rotationZ = value
        case .lineColor:
            self.lineColor = value
        case .lineWidth:
            self.lineWidth = value
        case .blur:
            self.blur = value
        case .blendMode:
            self.blendMode = value
        case .brightness:
            self.brightness = value
        case .colorInvert:
            self.colorInvert = value
        case .contrast:
            self.contrast = value
        case .hueRotation:
            self.hueRotation = value
        case .saturation:
            self.saturation = value
        case .pivot:
            self.pivot = value
        case .enabled:
            self.enabled = value
        case .blurRadius:
            self.blurRadius = value
        case .backgroundColor:
            self.backgroundColor = value
        case .isClipped:
            self.isClipped = value
        case .orientation:
            self.orientation = value
        case .padding:
            self.padding = value
        case .setupMode:
            self.setupMode = value
        case .cameraDirection:
            self.cameraDirection = value
        case .isCameraEnabled:
            self.isCameraEnabled = value
        case .isShadowsEnabled:
            self.isShadowsEnabled = value
            
        case .shape:
            self.shape = value
            
        case .strokePosition:
            self.strokePosition = value
        case .strokeWidth:
            self.strokeWidth = value
        case .strokeColor:
            self.strokeColor = value
        case .strokeStart:
            self.strokeStart = value
        case .strokeEnd:
            self.strokeEnd = value
            
        case .coordinateSystem:
            self.coordinateSystem = value
        case .cornerRadius:
            self.cornerRadius = value
        case .canvasLineColor:
            self.canvasLineColor = value
        case .canvasLineWidth:
            self.canvasLineWidth = value
        case .text:
            self.text = value
        case .fontSize:
            self.fontSize = value
        case .textAlignment:
            self.textAlignment = value
        case .verticalAlignment:
            self.verticalAlignment = value
        case .textDecoration:
            self.textDecoration = value
        case .textFont:
            self.textFont = value
        case .image:
            self.image = value
        case .video:
            self.video = value
        case .fitStyle:
            self.fitStyle = value
        case .clipped:
            self.clipped = value
        case .isAnimating:
            self.isAnimating = value
        case .progressIndicatorStyle:
            self.progressIndicatorStyle = value
        case .progress:
            self.progress = value
        case .model3D:
            self.model3D = value
        case .mapType:
            self.mapType = value
        case .mapLatLong:
            self.mapLatLong = value
        case .mapSpan:
            self.mapSpan = value
        case .isSwitchToggled:
            self.isSwitchToggled = value
        case .placeholderText:
            self.placeholderText = value
        case .startColor:
            self.startColor = value
        case .endColor:
            self.endColor = value
        case .startAnchor:
            self.startColor = value
        case .endAnchor:
            self.endAnchor = value
        case .centerAnchor:
            self.centerAnchor = value
        case .startAngle:
            self.startAngle = value
        case .endAngle:
            self.endAngle = value
        case .startRadius:
            self.startRadius = value
        case .endRadius:
            self.endRadius = value
            
        case .shadowColor:
            self.shadowColor = value
        case .shadowOpacity:
            self.shadowOpacity = value
        case .shadowRadius:
            self.shadowRadius = value
        case .shadowOffset:
            self.shadowOffset = value
        case .sfSymbol:
            self.sfSymbol = value
        case .strokeLineCap:
            self.strokeLineCap = value
        case .strokeLineJoin:
            self.strokeLineJoin = value
        case .videoURL:
            self.videoURL = value
        case .volume:
            self.volume = value
        case .spacingBetweenGridColumns:
            self.spacingBetweenGridColumns = value
        case .spacingBetweenGridRows:
            self.spacingBetweenGridRows = value
        case .itemAlignmentWithinGridCell:
            self.itemAlignmentWithinGridCell = value
        case .widthAxis:
            self.widthAxis = value
        case .heightAxis:
            self.heightAxis = value
        case .contentMode:
            self.contentMode = value
        case .minSize:
            self.minSize = value
        case .maxSize:
            self.maxSize = value
        case .spacing:
            self.spacing = value
        case .sizingScenario:
            self.sizingScenario = value
        case .isPinned:
            self.isPinned = value
        case .pinTo:
            self.pinTo = value
        case .pinAnchor:
            self.pinAnchor = value
        case .pinOffset:
            self.pinOffset = value
        case .layerPadding:
            self.layerPadding = value
        case .layerMargin:
            self.layerMargin = value
        case .offsetInGroup:
            self.offsetInGroup = value
        }
    }
}

extension LayerInputPort {
    @MainActor
    var layerNodeKeyPath: ReferenceWritableKeyPath<LayerNodeViewModel, LayerInputObserver> {
        switch self {
        case .position:
            return \.positionPort
        case .size:
            return \.sizePort
        case .scale:
            return \.scalePort
        case .anchoring:
            return \.anchoringPort
        case .opacity:
            return \.opacityPort
        case .zIndex:
            return \.zIndexPort
        case .masks:
            return \.masksPort
        case .color:
            return \.colorPort
        case .rotationX:
            return \.rotationXPort
        case .rotationY:
            return \.rotationYPort
        case .rotationZ:
            return \.rotationZPort
        case .lineColor:
            return \.lineColorPort
        case .lineWidth:
            return \.lineWidthPort
        case .blur:
            return \.blurPort
        case .blendMode:
            return \.blendModePort
        case .brightness:
            return \.brightnessPort
        case .colorInvert:
            return \.colorInvertPort
        case .contrast:
            return \.contrastPort
        case .hueRotation:
            return \.hueRotationPort
        case .saturation:
            return \.saturationPort
        case .pivot:
            return \.pivotPort
        case .enabled:
            return \.enabledPort
        case .blurRadius:
            return \.blurRadiusPort
        case .backgroundColor:
            return \.backgroundColorPort
        case .isClipped:
            return \.isClippedPort
        case .orientation:
            return \.orientationPort
        case .padding:
            return \.paddingPort
        case .setupMode:
            return \.setupModePort
        case .allAnchors:
            return \.allAnchorsPort
        case .cameraDirection:
            return \.cameraDirectionPort
        case .isCameraEnabled:
            return \.isCameraEnabledPort
        case .isShadowsEnabled:
            return \.isShadowsEnabledPort
            
        case .shape:
            return \.shapePort
        case .strokePosition:
            return \.strokePositionPort
        case .strokeWidth:
            return \.strokeWidthPort
        case .strokeColor:
            return \.strokeColorPort
        case .strokeStart:
            return \.strokeStartPort
        case .strokeEnd:
            return \.strokeEndPort
            
        case .coordinateSystem:
            return \.coordinateSystemPort
        case .cornerRadius:
            return \.cornerRadiusPort
        case .canvasLineColor:
            return \.canvasLineColorPort
        case .canvasLineWidth:
            return \.canvasLineWidthPort
        case .text:
            return \.textPort
        case .fontSize:
            return \.fontSizePort
        case .textAlignment:
            return \.textAlignmentPort
        case .verticalAlignment:
            return \.verticalAlignmentPort
        case .textDecoration:
            return \.textDecorationPort
        case .textFont:
            return \.textFontPort
        case .image:
            return \.imagePort
        case .video:
            return \.videoPort
        case .fitStyle:
            return \.fitStylePort
        case .clipped:
            return \.clippedPort
        case .isAnimating:
            return \.isAnimatingPort
        case .progressIndicatorStyle:
            return \.progressIndicatorStylePort
        case .progress:
            return \.progressPort
        case .model3D:
            return \.model3DPort
        case .mapType:
            return \.mapTypePort
        case .mapLatLong:
            return \.mapLatLongPort
        case .mapSpan:
            return \.mapSpanPort
        case .isSwitchToggled:
            return \.isSwitchToggledPort
        case .placeholderText:
            return \.placeholderTextPort
        case .startColor:
            return \.startColorPort
        case .endColor:
            return \.endColorPort
        case .startAnchor:
            return \.startAnchorPort
        case .endAnchor:
            return \.endAnchorPort
        case .centerAnchor:
            return \.centerAnchorPort
        case .startAngle:
            return \.startAnglePort
        case .endAngle:
            return \.endAnglePort
        case .startRadius:
            return \.startRadiusPort
        case .endRadius:
            return \.endRadiusPort
        case .shadowColor:
            return \.shadowColorPort
        case .shadowOpacity:
            return \.shadowOpacityPort
        case .shadowRadius:
            return \.shadowRadiusPort
        case .shadowOffset:
            return \.shadowOffsetPort
        case .sfSymbol:
            return \.sfSymbolPort
        case .strokeLineCap:
            return \.strokeLineCapPort
        case .strokeLineJoin:
            return \.strokeLineJoinPort
        case .videoURL:
            return \.videoURLPort
        case .volume:
            return \.volumePort
        case .spacingBetweenGridColumns:
            return \.spacingBetweenGridColumnsPort
        case .spacingBetweenGridRows:
            return \.spacingBetweenGridRowsPort
        case .itemAlignmentWithinGridCell:
            return \.itemAlignmentWithinGridCellPort
        case .widthAxis:
            return \.widthAxisPort
        case .heightAxis:
            return \.heightAxisPort
        case .contentMode:
            return \.contentModePort
        case .minSize:
            return \.minSizePort 
        case .maxSize:
            return \.maxSizePort
        case .spacing:
            return \.spacingPort
        case .sizingScenario:
            return \.sizingScenarioPort
        case .isPinned:
            return \.isPinnedPort
        case .pinTo:
            return \.pinToPort
        case .pinAnchor:
            return \.pinAnchorPort
        case .pinOffset:
            return \.pinOffsetPort
        case .layerPadding:
            return \.layerPaddingPort
        case .layerMargin:
            return \.layerMarginPort
        case .offsetInGroup:
            return \.offsetInGroupPort
        }
    }
    
    /// Converts port data from an unpacked state into a packed state.
    func packValues(from values: PortValues,
                    layer: Layer) -> PortValue {
        if !FeatureFlags.SUPPORTS_LAYER_UNPACK {
            fatalErrorIfDebug("Shouldn't have been called.")
            return .none
        }

        // Not relevant for all nodes
        guard let unpackedPortCount = self.unpackedPortCount(layer: layer) else {
            fatalErrorIfDebug("Shouldn't have been called for this port: \(self)")
            return .none
        }
        
        // Incoming values must match or exceed expected unpacked port count
        assertInDebug(unpackedPortCount <= values.count)
        
        // shorten values list to expected count for port
        let shortenedValues: PortValues = Array(values.prefix(upTo: unpackedPortCount))
        
        switch self {
        case .position:
            return shortenedValues.unpackedPositionCoercer()
            
        default:
            // TODO: define behavior for other nodes
            fatalError()
        }
    }
    
    /// Converts port data from unpacked state to packed state.
    /// Optional because not all ports support this.
    func unpackValues(from value: PortValue) -> PortValues? {
        if !FeatureFlags.SUPPORTS_LAYER_UNPACK {
            fatalErrorIfDebug("Shouldn't have been called.")
            return []
        }
        
        switch self {
        case .position:
            guard let position = value.getPosition else {
                fatalErrorIfDebug()
                return [value]
            }
            
            return [.number(position.x), .number(position.y)]
            
        default:
            // TODO: get to other types
            if FeatureFlags.SUPPORTS_LAYER_UNPACK {
//                fatalError("Support other types")
            }
            
            return nil
        }
    }
}

extension LayerInputType {
    /// Key paths for parent layer view model
    @MainActor
    var layerNodeKeyPath: ReferenceWritableKeyPath<LayerNodeViewModel, InputLayerNodeRowData> {
        let portKeyPath = self.layerInput.layerNodeKeyPath
        
        switch self.portType {
        case .packed:
            return portKeyPath.appending(path: \._packedData)
        case .unpacked(let unpackedType):
            switch unpackedType {
            case .port0:
                return portKeyPath.appending(path: \._unpackedData.port0)
            case .port1:
                return portKeyPath.appending(path: \._unpackedData.port1)
            case .port2:
                return portKeyPath.appending(path: \._unpackedData.port2)
            case .port3:
                return portKeyPath.appending(path: \._unpackedData.port3)
            }
        }
    }
}

extension LayerInputEntity {
    func getInputData(from portType: LayerInputKeyPathType) -> LayerInputDataEntity? {
        switch portType {
        case .packed:
            return self.packedData
        case .unpacked(let unpackedPortType):
            return self.unpackedData[safe: unpackedPortType.rawValue]
        }
    }
}

extension LayerInputPort {
    // shortLabel = used for property sidebar
    func label(_ useShortLabel: Bool = false) -> String {
        switch self {
            // Required everywhere
        case .position:
            return "Position"
        case .size:
            return "Size"
        case .scale:
            return "Scale"
        case .anchoring:
            return "Anchoring"
        case .startAnchor:
            return "Start Anchor"
        case .endAnchor:
            return "End Anchor"
        case .opacity:
            return "Opacity"
        case .zIndex:
            return "Z Index"
        case .masks:
            return "Masks"
        case .color:
            return "Color"
        case .startColor:
            return "Start Color"
        case .endColor:
            return "End Color"
        case .rotationX:
            return "Rotation X"
        case .rotationY:
            return "Rotation Y"
        case .rotationZ:
            return "Rotation Z"
        case .lineColor:
            return "Line Color"
        case .lineWidth:
            return "Line Width"
        case .blur:
            return "Blur"
        case .blendMode:
            return "Blend Mode"
        case .brightness:
            return "Brightness"
        case .colorInvert:
            return "Color Invert"
        case .contrast:
            return "Contrast"
        case .hueRotation:
            return "Hue Rotation"
        case .saturation:
            return "Saturation"
        case .pivot:
            return "Pivot"
        case .enabled:
            return "Enable"
        case .blurRadius:
            return "Blur Radius"
        case .backgroundColor:
            return "Background Color"
        case .isClipped:
            return "Clipped"
        case .orientation:
            return "Orientation"
        case .padding:
            return "Padding"
        case .setupMode:
            return "Setup Mode"
        case .allAnchors:
            return "AR Anchors"
        case .cameraDirection:
            return "Camera Direction"
        case .isCameraEnabled:
            return "Camera Enabled"
        case .isShadowsEnabled:
            return "Shadows Enabled"
            
        case .shape:
            return "Shape"
            
        case .strokePosition:
            return useShortLabel ? "Position" : "Stroke Position"
        case .strokeWidth:
            return useShortLabel ? "Width" : "Stroke Width"
        case .strokeColor:
            return useShortLabel ? "Color" : "Stroke Color"
        case .strokeStart:
            return useShortLabel ? "Start" : "Stroke Start"
        case .strokeEnd:
            return useShortLabel ? "End" : "Stroke End"
        case .strokeLineCap:
            return useShortLabel ? "Line Cap" : "Stroke Line Cap"
        case .strokeLineJoin:
            return useShortLabel ? "Line Join" : "Stroke Line Join"
        case .coordinateSystem:
            return "Coordinate System"
            
        case .canvasLineColor:
            return "Line Color"
        case .canvasLineWidth:
            return "Line Width"
        case .cornerRadius:
            return "Corner Radius"
        case .text:
            return "Text"
        case .fontSize:
            return "Font Size"
        case .textAlignment:
            return useShortLabel ? "Alignment" : "Text Alignment"
        case .verticalAlignment:
            return "Vertical Alignment"
        case .textDecoration:
            return useShortLabel ? "Decoration" : "Text Decoration"
        case .textFont:
            return useShortLabel ? "Font" : "Text Font"
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .fitStyle:
            return "Fit Style"
        case .clipped:
            return "Clipped"
        case .isAnimating:
            return "Animating"
        case .progressIndicatorStyle:
            return "Style"
        case .progress:
            return "Progress"
        case .model3D:
            return "3D Model"
        case .mapType:
            return "Map Style"
        case .mapLatLong:
            return "Lat/Long"
        case .mapSpan:
            return "Span"
        case .isSwitchToggled:
            return "Toggle"
        case .placeholderText:
            return "Placeholder"
        case .centerAnchor:
            return "Center Anchor"
        case .startAngle:
            return "Start Angle"
        case .endAngle:
            return "End Angle"
        case .startRadius:
            return "Start Radius"
        case .endRadius:
            return "End Radius"
            
        case .shadowColor:
            return useShortLabel ? "Color" : "Shadow Color"
        case .shadowOpacity:
            return useShortLabel ? "Opacity" : "Shadow Opacity"
        case .shadowRadius:
            return useShortLabel ? "Radius" : "Shadow Radius"
        case .shadowOffset:
            return useShortLabel ? "Offset" : "Shadow Offset"
        case .sfSymbol:
            return "SF Symbol"
            
        case .videoURL:
            return "Video URL"
        case .volume:
            return "Volume"
            
        case .spacingBetweenGridColumns:
            return "Column Spacing"
        case .spacingBetweenGridRows:
            return "Row Spacing"
        case .itemAlignmentWithinGridCell:
            return "Cell Anchoring"
            
        case .widthAxis:
            return "Width Axis"
        case .heightAxis:
            return "Height Axis"
        case .contentMode:
            return "Content Mode"
        case .minSize:
            return "Min Size"
        case .maxSize:
            return "Max Size"
        case .spacing:
            return "Spacing"
        case .sizingScenario:
//            return "Sizing Scenario"
            return "Sizing"
        
        case .isPinned:
            return "Pinned"
        case .pinTo:
            return "Pin To"
        case .pinAnchor:
            return useShortLabel ? "Anchor" : "Pin Anchor"
        case .pinOffset:
            return useShortLabel ? "Offset" : "Pin Offset"
        
        case .layerPadding:
            return useShortLabel ? "Padding" : "Layer Padding"
        case .layerMargin:
            return useShortLabel ? "Margin" : "Layer Margin"
        case .offsetInGroup:
            return useShortLabel ? "Offset" : "Offset in Group"
        }
    }

    var shouldResetGraphPreviews: Bool {
        switch self {
        case .zIndex, .masks, .isPinned, .pinTo:
            return true
        default:
            return false
        }
    }
    
    func unpackedPortCount(layer: Layer) -> Int? {
        let fakeValue = self.getDefaultValue(for: layer)
        let fakeUnpackedValues = self.unpackValues(from: fakeValue)
        return fakeUnpackedValues?.count
    }
}

extension LayerInputEntity {
    static let empty: Self = .init(packedData: .empty,
                                   unpackedData: [])
    
    /// Gets all encoded values, without concern for pack/unpack state.
    var encodedValues: [PortValues?] {
        switch self.mode {
        case .packed:
            return [self.packedData.inputPort.values]
        case .unpacked:
            return self.unpackedData.map { $0.inputPort.values }
        }
    }
    
    var mode: LayerInputMode {
        if self.unpackedData.contains(where: { $0.canvasItem.isDefined }) {
            return .unpacked
        }
        
        return .packed
    }
    
    var canvasItems: [CanvasNodeEntity] {
        switch self.mode {
        case .packed:
            if let canvas = self.packedData.canvasItem {
                return [canvas]
            }
            
            return []
        case .unpacked:
            return self.unpackedData.compactMap {
                $0.canvasItem
            }
        }
    }
    
    var inputConnections: [NodeConnectionType] {
        switch self.mode {
        case .packed:
            return [self.packedData.inputPort]
        case .unpacked:
            return self.unpackedData.map { $0.inputPort }
        }
    }
    
    var allInputData: [LayerInputDataEntity] {
        switch self.mode {
        case .packed:
            return [self.packedData]
        case .unpacked:
            return self.unpackedData
        }
    }
}
