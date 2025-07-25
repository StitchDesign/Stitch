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
    static let DEFAULT_FONT_SIZE = 18.0
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
            guard let unpackedValues = defaultPackedValue.unpackValues() else {
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
                // TODO: which is better for a default size for text? Auto = fixed size
                // TODO: Hug is a bad size for simple text cases? we don't position the newly-created via in range
//                return .size(.init(width: .hug, height: .hug))
                return .size(.init(width: .auto, height: .auto))
            case .group:
                return .size(.DEFAULT_LAYER_GROUP_SIZE)
            default:
                return .size(.LAYER_DEFAULT_SIZE)
            }
        case .scale:
            return .number(1)
        case .anchoring:
//            return .anchoring(.defaultAnchoring)
            return .anchoring(.DEFAULT_ANCHORING_FOR_SWIFTUI_AI) // center
        case .opacity:
            return defaultOpacity
        case .zIndex:
            return .number(.zero)
        case .masks:
            return .bool(false)
        case .color:
            switch layer {
            case .text, .textField:
                return .color(.black)
            default:
                return .color(initialLayerColor())
            }
            
        case .rotationX:
            return .number(.zero)
        case .rotationY:
            return .number(.zero)
        case .rotationZ:
            return .number(.zero)
        
        // TODO: remove these? Redundant vs `canvasLineColor` and `canvasLineWidth`
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
        case .anchorEntity:
            return .anchorEntity(nil)
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
            
        case .layerGroupAlignment:
            // return .anchoring(.defaultAnchoring)
            // Note: .center matches SwiftUI default
            return .anchoring(.DEFAULT_ANCHORING_FOR_SWIFTUI_AI)
            
        case .materialThickness:
            return .materialThickness(.defaultMaterialThickness)
        case .deviceAppearance:
            return .deviceAppearance(.defaultDeviceAppearance)
        case .scrollContentSize:
            return .size(.zero)
        case .scrollXEnabled:
            return .bool(NativeScrollInteractionNode.defaultScrollXEnabled)
        case .scrollJumpToXStyle:
            return .scrollJumpStyle(.scrollJumpStyleDefault)
        case .scrollJumpToX:
            return .pulse(.zero)
        case .scrollJumpToXLocation:
            return .number(.zero)
        case .scrollYEnabled:
            return .bool(NativeScrollInteractionNode.defaultScrollYEnabled)
        case .scrollJumpToYStyle:
            return .scrollJumpStyle(.scrollJumpStyleDefault)
        case .scrollJumpToY:
            return .pulse(.zero)
        case .scrollJumpToYLocation:
            return .number(.zero)
        case .transform3D:
            return .transform(.zero)
        case .isEntityAnimating:
            return .bool(true)
        case .translation3DEnabled:
            return .bool(false)
        case .rotation3DEnabled:
            return .bool(false)
        case .scale3DEnabled:
            return .bool(false)
        case .size3D:
            return .point3D(.init(x: 100, y: 100, z: 100))
        case .isMetallic:
            return .bool(false)
        case .radius3D:
            return .number(100)
        case .height3D:
            return .number(100)
        case .isScrollAuto:
            return .bool(true)
        case .beginEditing:
            return pulseDefaultFalse
        case .endEditing:
            return pulseDefaultFalse
        case .setText:
            return pulseDefaultFalse
        case .textToSet:
            return stringDefault
        case .isSecureEntry:
            return boolDefaultFalse
        case .isSpellCheckEnabled:
            return boolDefaultTrue
        case .keyboardType:
            return KeyboardType.defaultKeyboardTypePortValue
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
        case .layerGroupAlignment:
            return \.layerGroupAlignmentPort
        case .materialThickness:
            return \.materialThicknessPort
        case .deviceAppearance:
            return \.deviceAppearancePort
        case .scrollContentSize:
            return \.scrollContentSizePort
        case .scrollXEnabled:
            return \.scrollXEnabledPort
        case .scrollJumpToXStyle:
            return \.scrollJumpToXStylePort
        case .scrollJumpToX:
            return \.scrollJumpToXPort
        case .scrollJumpToXLocation:
            return \.scrollJumpToXLocationPort
        case .scrollYEnabled:
            return \.scrollYEnabledPort
        case .scrollJumpToYStyle:
            return \.scrollJumpToYStylePort
        case .scrollJumpToY:
            return \.scrollJumpToYPort
        case .scrollJumpToYLocation:
            return \.scrollJumpToYLocationPort
        case .transform3D:
            return \.transform3DPort
        case .anchorEntity:
            return \.anchorEntityPort
        case .isEntityAnimating:
            return \.isEntityAnimatingPort
        case .translation3DEnabled:
            return \.translation3DEnabledPort
        case .rotation3DEnabled:
            return \.rotation3DEnabledPort
        case .scale3DEnabled:
            return \.scale3DEnabledPort
        case .size3D:
            return \.size3DPort
        case .isMetallic:
            return \.isMetallicPort
        case .radius3D:
            return \.radius3DPort
        case .height3D:
            return \.height3DPort
        case .isScrollAuto:
            return \.isScrollAutoPort
        case .beginEditing:
            return \.beginEditingPort
        case .endEditing:
            return \.endEditingPort
        case .setText:
            return \.setTextPort
        case .textToSet:
            return \.textToSetPort
        case .isSecureEntry:
            return \.isSecureEntryPort
        case .isSpellCheckEnabled:
            return \.isSpellCheckEnabledPort
        case .keyboardType:
            return \.keyboardTypePort
        }
    }
    
    var supportsLoopedTypes: Bool {
        // MARK: no longer used
        false
//        switch self {
//        default:
//            return false
//        }
    }
}

extension LayerViewModel {
    /// Key paths for children preview layers.
    @MainActor
    func getValue(for inputType: LayerInputPort) -> PortValue {
        switch inputType {
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
        case .beginEditing:
            return self.beginEditing
        case .endEditing:
            return self.endEditing
        case .setText:
            return self.setText
        case .textToSet:
            return self.textToSet
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
            return self.startAnchor
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
        case .layerGroupAlignment:
            return self.layerGroupAlignment
        case .deviceAppearance:
            return self.deviceAppearance
        case .materialThickness:
            return self.materialThickness
        case .scrollContentSize:
            return self.scrollContentSize
        case .scrollXEnabled:
            return self.scrollXEnabled
        case .scrollJumpToXStyle:
            return self.scrollJumpToXStyle
        case .scrollJumpToX:
            return self.scrollJumpToX
        case .scrollJumpToXLocation:
            return self.scrollJumpToXLocation
        case .scrollYEnabled:
            return self.scrollYEnabled
        case .scrollJumpToYStyle:
            return self.scrollJumpToYStyle
        case .scrollJumpToY:
            return self.scrollJumpToY
        case .scrollJumpToYLocation:
            return self.scrollJumpToYLocation
        case .transform3D:
            return self.transform3D
        case .anchorEntity:
            return self.anchorEntity
        case .isEntityAnimating:
            return self.isEntityAnimating
        case .translation3DEnabled:
            return self.translation3DEnabled
        case .rotation3DEnabled:
            return self.rotation3DEnabled
        case .scale3DEnabled:
            return self.scale3DEnabled
        case .size3D:
            return self.size3D
        case .isMetallic:
            return self.isMetallic
        case .radius3D:
            return self.radius3D
        case .height3D:
            return self.height3D
        case .isScrollAuto:
            return self.isScrollAuto
        case .isSecureEntry:
            return self.isSecureEntry
        case .isSpellCheckEnabled:
            return self.isSpellCheckEnabled
        case .keyboardType:
            return self.keyboardType
        }
    }
    
    /// Key paths for children preview layers.
    @MainActor
    func updatePreviewLayerInput(_ value: PortValue,
                                 inputType: LayerInputPort) {
        switch inputType {
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
        case .beginEditing:
            self.beginEditing = value
        case .endEditing:
            self.endEditing = value
        case .setText:
            self.setText = value
        case .textToSet:
            self.textToSet = value
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
            self.startAnchor = value
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
        case .layerGroupAlignment:
            self.layerGroupAlignment = value
        case .deviceAppearance:
            self.deviceAppearance = value
        case .materialThickness:
            self.materialThickness = value
        case .scrollContentSize:
            self.scrollContentSize = value
        case .scrollXEnabled:
            self.scrollXEnabled = value
        case .scrollJumpToXStyle:
            self.scrollJumpToXStyle = value
        case .scrollJumpToX:
            self.scrollJumpToX = value
        case .scrollJumpToXLocation:
            self.scrollJumpToXLocation = value
        case .scrollYEnabled:
            self.scrollYEnabled = value
        case .scrollJumpToYStyle:
            self.scrollJumpToYStyle = value
        case .scrollJumpToY:
            self.scrollJumpToY = value
        case .scrollJumpToYLocation:
            self.scrollJumpToYLocation = value
        case .transform3D:
            self.transform3D = value
            
            // Updates transform specifcally when layer nodes are recalculated, in turn updating the values used for prototype restart. This is in conjunction to our manual check at graph step which only updates fields without impacting prototype restart.
            if let model3D = self.mediaObject?.model3DEntity {
                Model3DLayerNode.updateTransform(entity: model3D,
                                                 layerViewModel: self)
            }
            
        case .anchorEntity:
            self.anchorEntity = value
        case .isEntityAnimating:
            self.isEntityAnimating = value
        case .translation3DEnabled:
            self.translation3DEnabled = value
        case .rotation3DEnabled:
            self.rotation3DEnabled = value
        case .scale3DEnabled:
            self.scale3DEnabled = value
        case .size3D:
            self.size3D = value
        case .isMetallic:
            self.isMetallic = value
        case .radius3D:
            self.radius3D = value
        case .height3D:
            self.height3D = value
        case .isScrollAuto:
            self.isScrollAuto = value
        case .isSecureEntry:
            self.isSecureEntry = value
        case .isSpellCheckEnabled:
            self.isSpellCheckEnabled = value
        case .keyboardType:
            self.keyboardType = value
        }
    }
}

extension LayerInputPort {
//    var layerNodeKeyPath: ReferenceWritableKeyPath<LayerNodeViewModel, LayerInputObserver> {
    var layerNodeKeyPath: KeyPath<LayerNodeViewModel, LayerInputObserver> {
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
        case .beginEditing:
            return \.beginEditingPort
        case .endEditing:
            return \.endEditingPort
        case .setText:
            return \.setTextPort
        case .textToSet:
            return \.textToSetPort
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
        case .layerGroupAlignment:
            return \.layerGroupAlignmentPort
        case .materialThickness:
            return \.materialThicknessPort
        case .deviceAppearance:
            return \.deviceAppearancePort
        case .scrollContentSize:
            return \.scrollContentSizePort
        case .scrollXEnabled:
            return \.scrollXEnabledPort
        case .scrollJumpToXStyle:
            return \.scrollJumpToXStylePort
        case .scrollJumpToX:
            return \.scrollJumpToXPort
        case .scrollJumpToXLocation:
            return \.scrollJumpToXLocationPort
        case .scrollYEnabled:
            return \.scrollYEnabledPort
        case .scrollJumpToYStyle:
            return \.scrollJumpToYStylePort
        case .scrollJumpToY:
            return \.scrollJumpToYPort
        case .scrollJumpToYLocation:
            return \.scrollJumpToYLocationPort
        case .transform3D:
            return \.transform3DPort
        case .anchorEntity:
            return \.anchorEntityPort
        case .isEntityAnimating:
            return \.isEntityAnimatingPort
        case .translation3DEnabled:
            return \.translation3DEnabledPort
        case .rotation3DEnabled:
            return \.rotation3DEnabledPort
        case .scale3DEnabled:
            return \.scale3DEnabledPort
        case .size3D:
            return \.size3DPort
        case .isMetallic:
            return \.isMetallicPort
        case .radius3D:
            return \.radius3DPort
        case .height3D:
            return \.height3DPort
        case .isScrollAuto:
            return \.isScrollAutoPort
        case .isSecureEntry:
            return \.isSecureEntryPort
        case .isSpellCheckEnabled:
            return \.isSpellCheckEnabledPort
        case .keyboardType:
            return \.keyboardPort
        }
    }
    
    /// Converts port data from an unpacked state into a packed state.
    func packValues(from values: PortValues,
                    layer: Layer) -> PortValue {
        // Not relevant for all nodes
        guard let unpackedPortCount = self.unpackedPortCount(layer: layer) else {
            fatalErrorIfDebug("Shouldn't have been called for this port: \(self)")
            return .none
        }
        
        let defaultPackedValue: PortValue = self.getDefaultValue(for: layer)
        
        return values.packValues(unpackedPortCount: unpackedPortCount,
                                 type: defaultPackedValue.toNodeType)
    }
}

extension PortValues {
    /// Converts port data from an unpacked state into a packed state.
    /// This function is specifically used by layers.
    func packValues(unpackedPortCount: Int,
                    type: NodeType) -> PortValue {
        let values = self
        
        // Incoming values must match or exceed expected unpacked port count
        assertInDebug(unpackedPortCount <= values.count)
                
        guard let result = values.pack(type: type) else {
            fatalErrorIfDebug()
            return .position(.zero)
        }
        
        return result
    }
    
    func packValues(type: NodeType) -> PortValue? {
        let values = self
        let unpackedPortCount = self.count
        
        // Incoming values must match or exceed expected unpacked port count
        assertInDebug(unpackedPortCount <= values.count)
                
        return values.pack(type: type)
    }
}

extension PortValue {
    /// Converts port data from unpacked state to packed state.
    /// Optional because not all ports support this.
    /// See also `PortValue.pack: PortValues -> PortValue?`
    func unpackValues() -> PortValues? {
        let value = self
        
        // Unpacking logic should probably be by the passed-in PortValue, rather than the layer-input-type, since most
                
        // Can we reuse some logic from `PortValue -> FieldViewModels` ?
        // PortValue.createFieldValues is from PortValue to FieldValues; but we need to return
        // Ah, you have field-editing logic that goes from
        
        switch value {
            
        case .size(let layerSize):
            return [
                .layerDimension(layerSize.width),
                .layerDimension(layerSize.height)
            ]
            
        case .position(let position):
            return [
                .number(position.x),
                .number(position.y)
            ]
            
        case .point3D(let point):
            return [
                .number(point.x),
                .number(point.y),
                .number(point.z)
            ]
            
        case .point4D(let point):
            return [
                .number(point.x),
                .number(point.y),
                .number(point.z),
                .number(point.w)
            ]
            
        case .padding(let padding):
            return [
                .number(padding.top),
                .number(padding.right),
                .number(padding.bottom),
                .number(padding.left)
            ]
            
        case .transform(let transform):
            return [
                .number(transform.positionX),
                .number(transform.positionY),
                .number(transform.positionZ),
                .number(transform.scaleX),
                .number(transform.scaleY),
                .number(transform.scaleZ),
                .number(transform.rotationX),
                .number(transform.rotationY),
                .number(transform.rotationZ)
            ]
          
        // LayerDimension cannot be unpacked, nor can ShapeCommand
            
        default:
            return nil
        }
    }
}

extension LayerInputPort {
    // For contexts where we MUST be accessing the packed data (e.g. input, not field, added to the graph)
    var packedLayerInputKeyPath: KeyPath<LayerNodeViewModel, InputLayerNodeRowData> {
        self.layerNodeKeyPath.appending(path: \._packedData)
    }
}

extension LayerInputType {
    
    /// Key paths for parent layer view model
    // var layerNodeKeyPath: ReferenceWritableKeyPath<LayerNodeViewModel, InputLayerNodeRowData> {
    var layerNodeKeyPath: KeyPath<LayerNodeViewModel, InputLayerNodeRowData> {
        let portKeyPath = self.layerInput.layerNodeKeyPath
        
        switch self.portType {
        case .packed:
            return self.layerInput.packedLayerInputKeyPath
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
            case .port4:
                return portKeyPath.appending(path: \._unpackedData.port4)
            case .port5:
                return portKeyPath.appending(path: \._unpackedData.port5)
            case .port6:
                return portKeyPath.appending(path: \._unpackedData.port6)
            case .port7:
                return portKeyPath.appending(path: \._unpackedData.port7)
            case .port8:
                return portKeyPath.appending(path: \._unpackedData.port8)
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
    // fka `shouldResetGraphPreviews`
    var shouldResortPreviewLayersIfChanged: Bool {
        switch self {
        case .zIndex, .masks, .isPinned, .pinTo, .orientation:
            return true
        default:
            return false
        }
    }
    
    func unpackedPortCount(layer: Layer) -> Int? {
        let fakeValue = self.getDefaultValue(for: layer)
        let fakeUnpackedValues = fakeValue.unpackValues()
        return fakeUnpackedValues?.count
    }
    
    /// Creates visual groupings of labels, used for 3D transform input.
    var transform3DLabelGroupings: [GroupedLayerInputData]? {
        switch self {
        case .transform3D:
            return [
                .init(label: "Position",
                      portRange: (0..<3)),
                .init(label: "Scale",
                      portRange: (3..<6)),
                .init(label: "Rotation",
                      portRange: (6..<9))
            ]
            
        default:
            return nil
        }
    }
    
    @MainActor var showsLabelForInspector: Bool {
        switch self {
        case .transform3D, .size3D:
            return false
            
        default:
            return true
        }
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
