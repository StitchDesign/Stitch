//
//  AIGraphDataLayerUtil_V0.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 7/15/25.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// MARK: - helpers here are redundant copies that we need for versioning

extension LayerInputPort {
    func getDefaultValueForAI(for layer: Layer) -> PortValue {
        switch self {
            // Required everywhere
        case .position:
            return .position(.zero)
        case .size:
            switch layer {
            case .image, .video, .realityView:
                return .size(.init(width: PreviewWindowDevice.DEFAULT_PREVIEW_SIZE.width,
                                   height: 200))
            case .canvasSketch:
                return .size(.init(width: 200, height: 200))
            case .map:
                return .size(.init(width: 200, height: 500))
            case .videoStreaming:
                return .size(.init(width: 300, height: 400))
            case .textField:
                return .size(.init(width: 300, height: 100))
            case .text:
                return .size(.init(width: .auto, height: .auto))
            case .group:
                return .size(.init(width: .fill, height: .fill))
            default:
                return .size(.init(width: 100, height: 100))
            }
        case .scale:
            return .number(1)
        case .anchoring:
            return .anchoring(.centerCenter)
        case .opacity:
            return .number(1.0)
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
            return .blendMode(.normal)
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
            return .padding(.init(top: .zero,
                                  right: .zero,
                                  bottom: .zero,
                                  left: .zero))
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
            return .layerStroke(.none)
        case .strokeWidth:
            return .number(4)
        case .strokeColor:
            return .color(falseColor)
        case .strokeStart:
            return .number(.zero)
        case .strokeEnd:
            return .number(1.0)
        case .strokeLineCap:
            return .strokeLineCap(.round)
        case .strokeLineJoin:
            return .strokeLineJoin(.round)
            
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
            return .textAlignment(.left)
        case .verticalAlignment:
            return .textVerticalAlignment(.top)
        case .textDecoration:
            return .textDecoration(.none)
        case .textFont:
            return .textFont(.init(fontChoice: .sf,
                                   fontWeight: .SF_regular))
        case .image, .video, .model3D:
            return .asyncMedia(nil)
        case .anchorEntity:
            return .anchorEntity(nil)
        case .fitStyle:
            return .fitStyle(.fill)
        case .clipped:
            return .bool(true)
        case .mapType:
            return .mapType(.standard)
        case .mapLatLong:
            return .position(DEFAULT_MAP_LAT_LONG_POSITION)
        case .mapSpan:
            return .position(DEFAULT_MAP_LAT_LONG_SPAN)
        case .isSwitchToggled:
            return .pulse(.zero)
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
            return .contentMode(.fit)
        case .minSize:
            return .size(.init(width: .auto, height: .auto))
        case .maxSize:
            return .size(.init(width: .auto, height: .auto))
        case .spacing:
            return .spacing(.number(.zero))
        case .sizingScenario:
            return .sizingScenario(.auto)
        case .isPinned:
            return .bool(false)
        case .pinTo:
            return .pinTo(.root)
        case .pinAnchor:
            return .anchoring(.topLeft)
        case .pinOffset:
            return .size(.init(width: .zero, height: .zero))
        case .layerPadding:
            return .padding(.init(top: .zero,
                                  right: .zero,
                                  bottom: .zero,
                                  left: .zero))
        case .layerMargin:
            return .padding(.init(top: .zero,
                                  right: .zero,
                                  bottom: .zero,
                                  left: .zero))
        case .offsetInGroup:
            return .size(.init(width: .zero, height: .zero))
        case .layerGroupAlignment:
            return .anchoring(.topLeft)
        case .materialThickness:
            return .materialThickness(.regular)
        case .deviceAppearance:
            return .deviceAppearance(.system)
        case .scrollContentSize:
            return .size(.init(width: .zero, height: .zero))
        case .scrollXEnabled:
            return .bool(NativeScrollInteractionNode.defaultScrollXEnabled)
        case .scrollJumpToXStyle:
            return .scrollJumpStyle(.instant)
        case .scrollJumpToX:
            return .pulse(.zero)
        case .scrollJumpToXLocation:
            return .number(.zero)
        case .scrollYEnabled:
            return .bool(NativeScrollInteractionNode.defaultScrollYEnabled)
        case .scrollJumpToYStyle:
            return .scrollJumpStyle(.instant)
        case .scrollJumpToY:
            return .pulse(.zero)
        case .scrollJumpToYLocation:
            return .number(.zero)
        case .transform3D:
            return .transform(.init())
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
            return .pulse(.zero)
        case .endEditing:
            return .pulse(.zero)
        case .setText:
            return .pulse(.zero)
        case .textToSet:
            return stringDefault
        case .isSecureEntry:
            return .bool(false)
        case .isSpellCheckEnabled:
            return .bool(true)
        case .keyboardType:
            return .keyboardType(.defaultKeyboard)
        }
    }
    
    /// Keypath mapping to this schema version.
    var schemaPortKeyPathForAI: WritableKeyPath<LayerNodeEntity_V32.LayerNodeEntity, LayerInputEntity_V32.LayerInputEntity> {
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
}
