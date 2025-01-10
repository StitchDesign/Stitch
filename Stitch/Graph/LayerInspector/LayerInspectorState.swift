//
//  LayerInspectorState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import Foundation
import StitchSchemaKit

// layer node id + layer input (regardless of packed or unpacked)
struct LayerPortCoordinate: Equatable, Hashable {
    let nodeId: NodeId
    let layerInputPort: LayerInputPort
}

// Can this really be identifiable ?
enum LayerInspectorRowId: Equatable, Hashable {
    case layerInput(LayerInputType) // Layer node inputs use keypaths
//    case layerInput(LayerPortCoordinate) // Layer node inputs use keypaths
    case layerOutput(Int) // Layer node outputs use port ids (ints)
}

typealias LayerInspectorRowIdSet = Set<LayerInspectorRowId>

@Observable
final class PropertySidebarObserver: Sendable {
        
    // Non-nil just if we have multiple layers selected
    @MainActor var inputsCommonToSelectedLayers: LayerInputPortSet?
    
    @MainActor var selectedProperty: LayerInspectorRowId?
    
    // Used for positioning flyouts; read and populated by every row,
    // even if row does not support a flyout or has no active flyout.
    // TODO: only needs to be the `y` value, since `x` is static (based on layer inspector's static width)
    @MainActor var propertyRowOrigins: [LayerInputPort: CGPoint] = .init()
    
    // Only layer inputs (not fields or outputs) can have flyouts
    @MainActor var flyoutState: PropertySidebarFlyoutState? = nil
    
    @MainActor var collapsedSections: Set<LayerInspectorSectionName> = .init()
    
    // NOTE: Specific to positioning the flyout when flyout's bottom edge could sit below graph's bottom edge
    @MainActor var safeAreaTopPadding: CGFloat = 0
    
    // TODO: why do we not need to worry about bottom padding from UIKitWrapper?
    // var safeAreaBottomPadding: CGFloat = 0
    
    init() { }
}

struct PropertySidebarFlyoutState: Equatable {
    
    // TODO: if each flyout has a known static size (static size required for UIKitWrapper i.e. keypress listening), then can use an enum static sizes here
    // Populated by the flyout view itself
    var flyoutSize: CGSize = .zero
    
    // User tapped this row, so we opened its flyout
    var flyoutInput: LayerInputPort
    var flyoutNode: NodeId
    
    var keyboardIsOpen: Bool = false
}

struct LayerInspectorSectionData: Equatable, Hashable {
    let name: LayerInspectorSectionName
    let inputs: LayerInputPortSet
}

extension LayerInspectorSectionData {
    init(_ name: LayerInspectorSectionName, 
         _ inputs: LayerInputPortSet) {
        self.name = name
        self.inputs = inputs
    }
}

extension LayerInspectorView {
//extension LayerInputTypeSet {
        
    // TODO: for tab purposes, exclude flyout fields (shadow inputs, padding)?
    // TODO: need to consolidate this logic across the LayerInspectorRowView UI ?
    @MainActor
    static func layerInspectorRowsInOrder(_ layer: Layer) -> [LayerInspectorSectionData] {
        [
            .init(.sizing, Self.sizing),
            .init(.positioning, Self.positioning),
            .init(.common, Self.common),
            .init(.group, layer == .group ? Self.groupLayer : []),
            .init(.scrolling, layer == .group ? Self.groupScrolling : []),
            .init(.pinning, Self.pinning),
            .init(.typography, layer.supportsTypographyInputs ? Self.text : []),
            .init(.stroke, layer.supportsStrokeInputs ? Self.stroke : []),
            .init(.rotation, layer.supportsRotationInputs ? Self.rotation : []),
            .init(.layerEffects, layer.supportsLayerEffectInputs ? Self.layerEffects : []),
        ]
    }
    
    @MainActor
    static let unfilteredLayerInspectorRowsInOrder: [LayerInspectorSectionData] =
        [
            .init(.media, Self.media),
            .init(.realityTransformation, Self.realityTransformation),
            .init(.gestures3D, Self.gestures3D),
            .init(.sizing, Self.sizing),
            .init(.positioning, Self.positioning),
            .init(.common, Self.common),
            .init(.group, Self.groupLayer),
            .init(.scrolling, Self.groupScrolling),
            .init(.pinning, Self.pinning),
            .init(.typography, Self.text),
            .init(.stroke, Self.stroke),
            .init(.rotation, Self.rotation),
            .init(.layerEffects, Self.layerEffects)
        ]
            
    @MainActor
    static let positioning: LayerInputPortSet = [
        .position,
        .anchoring,
        .zIndex,
        .offsetInGroup
    ]
    
    @MainActor
    static let sizing: LayerInputPortSet = [
        
        .sizingScenario,

        // Aspect Ratio
        .widthAxis,
        .heightAxis,
        .contentMode, // Don't show?

        .size,

            // Min and max size
        .minSize,
        .maxSize,
    ]
    
    @MainActor
    static let media: LayerInputPortSet = [
        // Imports
        .image,
        .video,
        .model3D,
        .anchorEntity,
        .isEntityAnimating,
        .fitStyle
    ]
    
    @MainActor
    static let realityTransformation: LayerInputPortSet = [
        .transform3D
    ]
    
    @MainActor
    static let gestures3D: LayerInputPortSet = [
        .translation3DEnabled,
        .scale3DEnabled,
        .rotation3DEnabled
    ]
    
    @MainActor
    static let common: LayerInputPortSet = [
        
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
    
    @MainActor
    static let groupLayer: LayerInputPortSet = [
        .orientation,
        .backgroundColor, // actually for many layers?
        .isClipped,
        .spacing,
        // Grid
        .spacingBetweenGridColumns,
        .spacingBetweenGridRows,
        .itemAlignmentWithinGridCell
    ]
    
    @MainActor
    static let groupScrolling: LayerInputPortSet = [
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
   
    @MainActor
    static let pinning: LayerInputPortSet = LayerInputPortSet.pinning
    
    @MainActor
    static let text: LayerInputPortSet = [
        .text,
        .placeholderText,
        .fontSize,
        .textAlignment,
        .verticalAlignment,
        .textDecoration,
        .textFont,
    ]
    
    @MainActor
    static let stroke: LayerInputPortSet = [
        .strokePosition,
        .strokeWidth,
        .strokeColor,
        .strokeStart,
        .strokeEnd,
        .strokeLineCap,
        .strokeLineJoin
    ]
    
    @MainActor
    static let rotation: LayerInputPortSet = [
        .rotationX,
        .rotationY,
        .rotationZ
    ]
    
    @MainActor
    static let shadow: LayerInputPortSet = [
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ]
    
    @MainActor
    static let layerEffects: LayerInputPortSet = [
        SHADOW_FLYOUT_LAYER_INPUT_PROXY,
        .blur, // use .blur; .blurRadius is ignored
        .blendMode,
        .brightness,
        .colorInvert,
        .contrast,
        .hueRotation,
        .saturation
    ]
}

// TODO: derive this from exsiting LayerNodeDefinition ? i.e. filter which sections we show by the LayerNodeDefinition's input list
extension Layer {
    
    // TODO: can you get rid of all these checks?
    @MainActor
    var supportsGroupInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.groupLayer).isEmpty
    }
        
    @MainActor
    var supportsTypographyInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.text).isEmpty
    }
    
    @MainActor
    var supportsStrokeInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.stroke).isEmpty
    }

    // TODO: don't *all* layers support x-y-z rotation?
    @MainActor
    var supportsRotationInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.rotation).isEmpty
    }
    
    // TODO: don't *all* layers support shadows?
    @MainActor
    var supportsShadowInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.shadow).isEmpty
    }
    
    // TODO: don't *all* layers support layer-effects? (Not HitArea ?)
    @MainActor
    var supportsLayerEffectInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.layerEffects).isEmpty
    }
}
