//
//  LayerInspectorState.swift
//  Stitch
//
//  Created by Christian J Clampitt on 6/24/24.
//

import Foundation
import StitchSchemaKit

// Can this really be identifiable ?
enum LayerInspectorRowId: Equatable, Hashable {
    case layerInput(LayerInputType) // Layer node inputs use keypaths
    case layerOutput(Int) // Layer node outputs use port ids (ints)
}

typealias LayerInspectorRowIdSet = Set<LayerInspectorRowId>

@Observable
final class PropertySidebarObserver {
        
    // Non-nil just if we have multiple layers selected
    var inputsCommonToSelectedLayers: LayerInputTypeSet?
    
    var selectedProperty: LayerInspectorRowId?
    
    // Used for positioning flyouts; read and populated by every row,
    // even if row does not support a flyout or has no active flyout.
    // TODO: only needs to be the `y` value, since `x` is static (based on layer inspector's static width)
    var propertyRowOrigins: [LayerInputPort: CGPoint] = .init()
    
    // Only layer inputs (not fields or outputs) can have flyouts
    var flyoutState: PropertySidebarFlyoutState? = nil
    
    var collapsedSections: Set<LayerInspectorSectionName> = .init()
    
    // NOTE: Specific to positioning the flyout when flyout's bottom edge could sit below graph's bottom edge
    var safeAreaTopPadding: CGFloat = 0
    
    // TODO: why do we not need to worry about bottom padding from UIKitWrapper?
    // var safeAreaBottomPadding: CGFloat = 0
}

struct PropertySidebarFlyoutState: Equatable {
    
    // TODO: if each flyout has a known static size (static size required for UIKitWrapper i.e. keypress listening), then can use an enum static sizes here
    // Populated by the flyout view itself
    var flyoutSize: CGSize = .zero
    
    // User tapped this row, so we opened its flyout
    var flyoutInput: LayerInputPort
    var flyoutNode: NodeId
    
    var keyboardIsOpen: Bool = false
    
    var input: InputCoordinate {
        // TODO: flyouts only for packed state?
        InputCoordinate(portType: .keyPath(.init(layerInput: flyoutInput,
                                                 portType: .packed)),
                        nodeId: self.flyoutNode)
    }
}

struct LayerInspectorSectionData: Equatable, Hashable {
    let name: LayerInspectorSectionName
    let inputs: LayerInputTypeSet
}

extension LayerInspectorSectionData {
    init(_ name: LayerInspectorSectionName, 
         _ inputs: LayerInputTypeSet) {
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
            .init(.group, layer.supportsGroupInputs ? Self.groupLayer : []),
            .init(.pinning, Self.pinning),
            .init(.typography, layer.supportsTypographyInputs ? Self.text : []),
            .init(.stroke, layer.supportsStrokeInputs ? Self.stroke : []),
            .init(.rotation, layer.supportsRotationInputs ? Self.rotation : []),
//            .init(.shadow, layer.supportsShadowInputs ? Self.shadow : []),
            .init(.layerEffects, layer.supportsLayerEffectInputs ? Self.effects : []),
        ]
    }
    
    @MainActor
    static let unfilteredLayerInspectorRowsInOrder: [LayerInspectorSectionData] =
        [
            .init(.sizing, Self.sizing),
            .init(.positioning, Self.positioning),
            .init(.common, Self.common),
            .init(.group, Self.groupLayer),
            .init(.pinning, Self.pinning),
            .init(.typography, Self.text),
            .init(.stroke, Self.stroke),
            .init(.rotation, Self.rotation),
//            .init(.shadow, Self.shadow),
            .init(.layerEffects, Self.effects)
        ]
            
    @MainActor
    static let positioning: LayerInputTypeSet = [
        .position,
        .anchoring,
        .zIndex,
        .offsetInGroup
    ]
    
    @MainActor
    static let sizing: LayerInputTypeSet = [
        
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
    
    // Includes some
    @MainActor
    static let common: LayerInputTypeSet = [
        
        // Required
        .scale,
        .opacity,
        .pivot, // pivot point for scaling; put with
        
//        .init(.shadow, layer.supportsShadowInputs ? Self.shadow : []),
        
        .masks,
        .clipped,
        
        .color, // Text color vs Rectangle color
        
        // Hit Area
        .enabled,
        .setupMode,
        
        // Model3D
        .isAnimating,
        
        // Shape layer node
        .shape,
        .coordinateSystem,
        
        // rectangle (and group?)
        .cornerRadius,
        
        // Canvas
        .canvasLineColor,
        .canvasLineWidth,
                
        // Media
        .image,
        .video,
        .model3D,
        .fitStyle,
        
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
        
        // SFSymbol
        .sfSymbol,
        
        // Video
        .videoURL,
        .volume,
        
        // Reality
        .allAnchors,
        .cameraDirection,
        .isCameraEnabled,
        .isShadowsEnabled,
        
        // Layer padding, margin
        .layerMargin,
        .layerPadding
    ]
    
    @MainActor
    static let groupLayer: LayerInputTypeSet = [
        .backgroundColor, // actually for many layers?
        .isClipped,
        
        .orientation,
        
        .padding,
        .spacing, // added
        
        // Grid
        .spacingBetweenGridColumns,
        .spacingBetweenGridRows,
        .itemAlignmentWithinGridCell
    ]
   
    @MainActor
    static let pinning: LayerInputTypeSet = LayerInputTypeSet.pinning
    
    @MainActor
    static let text: LayerInputTypeSet = [
        .text,
        .placeholderText,
        .fontSize,
        .textAlignment,
        .verticalAlignment,
        .textDecoration,
        .textFont,
    ]
    
    @MainActor
    static let stroke: LayerInputTypeSet = [
        .strokePosition,
        .strokeWidth,
        .strokeColor,
        .strokeStart,
        .strokeEnd,
        .strokeLineCap,
        .strokeLineJoin
    ]
    
    @MainActor
    static let rotation: LayerInputTypeSet = [
        .rotationX,
        .rotationY,
        .rotationZ
    ]
    
    @MainActor
    static let shadow: LayerInputTypeSet = [
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ]
    
    @MainActor
    static let effects: LayerInputTypeSet = [
        SHADOW_FLYOUT_LAYER_INPUT_PROXY,
        .blur, // blur vs blurRadius ?
        .blurRadius,
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
        return !layerInputs.intersection(LayerInspectorView.effects).isEmpty
    }
}
