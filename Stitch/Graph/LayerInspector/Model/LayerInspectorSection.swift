//
//  LayerInspectorSection.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 1/14/25.
//

import SwiftUI
import StitchSchemaKit

enum LayerInspectorSection: String, CaseIterable, Identifiable, Hashable {
    case media = "Media"
    case geometry3D = "3D Geometry"
    case realityTransformation = "3D Transformation"
    case gestures3D = "3D Gestures"
    case sizing = "Sizing"
    case positioning = "Positioning"
    case common = "Common"
    case group = "Group"
    case scrolling = "Scrolling" // Better?: "Group Scrolling"
    case pinning = "Pinning"
    case typography = "Typography"
    case stroke = "Stroke"
    case rotation = "Rotation"
    case layerEffects = "Layer Effects"
}

extension LayerInspectorSection {
    var id: String { self.rawValue }
    
    var sectionData: [LayerInputPort] {
        switch self {
        case .sizing:
            return [
                .sizingScenario,

                // Aspect Ratio
                .widthAxis,
                .heightAxis,
                .contentMode, // Don't show?

                .size,

                    // Min and max size
                .minSize,
                .maxSize
            ]
        
        case .positioning:
            return [
                .position,
                .anchoring,
                .zIndex,
                .offsetInGroup
            ]
        
        case .common:
            return [
                
                // Required
                .scale,
                .pivot, // pivot point for scaling; put with
                
                .opacity,
                
                // Material
                .materialThickness,
                .deviceAppearance,
                
                // Canvas
                .canvasLineColor,
                .canvasLineWidth,
                
                // SFSymbol
                .sfSymbol,
                
                .color, // Text color vs Rectangle color
                
                // Shape layer node
                .shape,
                .coordinateSystem,
                
        //        .init(.shadow, layer.supportsShadowInputs ? Self.shadow : []),
                
                
                .masks,
                .clipped,
                
                // Hit Area
                .enabled,
                .setupMode,
                
                // Model3D
                .isAnimating,
                        
                // rectangle (and group?)
                .cornerRadius,
                    
                // Progress Indicator
                .progressIndicatorStyle,
                .progress,
                
                // Map
                .mapType,
                .mapLatLong,
                .mapSpan,
                
                // Switch
                .isSwitchToggled,
                
                // TODO: what are these inputs, actually?
                .lineColor,
                .lineWidth,
                
                // Gradients
                .startColor,
                .endColor,
                .startAnchor,
                .endAnchor,
                .centerAnchor,
                .startAngle,
                .endAngle,
                .startRadius,
                .endRadius,
                
                // Video
                .videoURL,
                .volume,
                
                // Reality
                .cameraDirection,
                .isCameraEnabled,
                .isShadowsEnabled,
                
                // Layer padding, margin
                .layerMargin,
                .layerPadding
            ]
        
        case .group:
            return [
                .orientation,
                .layerGroupAlignment,
                .backgroundColor, // actually for many layers?
                .isClipped,
                .spacing,
                // Grid
                .spacingBetweenGridColumns,
                .spacingBetweenGridRows,
                .itemAlignmentWithinGridCell,
                
            ]
        
        case .scrolling:
            return [
                .scrollContentSize,
                
                .scrollXEnabled,
                .scrollJumpToXStyle,
                .scrollJumpToX,
                .scrollJumpToXLocation,
                
                .scrollYEnabled,
                .scrollJumpToYStyle,
                .scrollJumpToY,
                .scrollJumpToYLocation
            ]
        
        case .pinning:
            return [
                .isPinned,
                .pinTo,
                .pinAnchor,
                .pinOffset
            ]
        
        case .typography:
            return [
                .text,
                .placeholderText,
                .textFont,
                .fontSize,
                .textAlignment,
                .verticalAlignment,
                .textDecoration
            ]
        
        case .stroke:
            return [
                .strokePosition,
                .strokeWidth,
                .strokeColor,
                .strokeStart,
                .strokeEnd,
                .strokeLineCap,
                .strokeLineJoin
            ]
        
        case .rotation:
            return [
                .rotationX,
                .rotationY,
                .rotationZ
            ]
        
        case .layerEffects:
            return [
                SHADOW_FLYOUT_LAYER_INPUT_PROXY,
                .blur, // use .blur; .blurRadius is ignored
                .blendMode,
                .brightness,
                .colorInvert,
                .contrast,
                .hueRotation,
                .saturation
            ]
        
        case .media:
            return [
                // Imports
                .image,
                .video,
                .model3D,
                .anchorEntity,
                .isEntityAnimating,
                .fitStyle
            ]
        
        case .realityTransformation:
            return [
                .transform3D
            ]
        
        case .gestures3D:
            return [
                .translation3DEnabled,
                .scale3DEnabled,
                .rotation3DEnabled
            ]
        
        case .geometry3D:
            return [
                .size3D,
                .radius3D,
                .height3D,
                .isMetallic
            ]
        }
    }
    
    @MainActor
    static let shadow: [LayerInputPort] = [
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ]
    
    @MainActor
    func displaysOnTabbing(layer: Layer) -> Bool {
        switch self {
        case .sizing, .positioning, .common, .pinning:
            return true
        
        case .group, .scrolling:
            return layer == .group
        
        default:
            return layer.supportsInputs(for: self)
        }
    }
}
