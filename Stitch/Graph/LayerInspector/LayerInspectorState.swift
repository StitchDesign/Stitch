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
    var selectedProperty: LayerInspectorRowId?
    
    // Used for positioning flyouts; read and populated by every row,
    // even if row does not support a flyout or has no active flyout.
    // TODO: use `x` of left edge of property sidebar
    var propertyRowOrigins: [LayerInputType: CGPoint] = .init()
    
    // Only layer inputs (not fields or outputs) can have flyouts
    var flyoutState: PropertySidebarFlyoutState? = nil
    
    var collapsedSections: Set<LayerInspectorSectionName> = .init()
    
    var safeAreaTopPadding: CGFloat = 0
    
    // TODO: why do we not need to worry about bottom padding from UIKitWrapper?
    // var safeAreaBottomPadding: CGFloat = 0
}

struct PropertySidebarFlyoutState: Equatable {
    
    // TODO: if each flyout has a known static size (static size required for UIKitWrapper i.e. keypress listening), then can use an enum static sizes here
    // Populated by the flyout view itself
    var flyoutSize: CGSize = .zero
    
    // User tapped this row, so we opened its flyout
    var flyoutInput: LayerInputType
    var flyoutNode: NodeId
    
    var input: InputCoordinate {
        InputCoordinate(portType: .keyPath(self.flyoutInput),
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
        
    // TODO: for tab purposes, exclude flyout fields (shadow inputs, padding)?
    // TODO: need to consolidate this logic across the LayerInspectorRowView UI ?
    @MainActor
    static func layerInspectorRowsInOrder(_ layer: Layer) -> [LayerInspectorSectionData] {
        [
            .init(.sizing, Self.sizing),
            .init(.positioning, Self.positioning),
            .init(.common, Self.common),
            .init(.group, layer.supportsGroupInputs ? Self.groupLayer : []),
            .init(.typography, layer.supportsTypographyInputs ? Self.text : []),
            .init(.stroke, layer.supportsStrokeInputs ? Self.stroke : []),
            .init(.rotation, layer.supportsRotationInputs ? Self.rotation : []),
//            .init(.shadow, layer.supportsShadowInputs ? Self.shadow : []),
            .init(.layerEffects, layer.supportsLayerEffectInputs ? Self.effects : []),
        ]
    }
    
    @MainActor
    static func firstSectionName(_ layer: Layer) -> LayerInspectorSectionName? {
        Self.layerInspectorRowsInOrder(layer).first?.name
    }
        
    @MainActor
    static let positioning: LayerInputTypeSet = [
        .position,
        .anchoring,
        .zIndex,
        // .offset // TO BE ADED
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
        .isShadowsEnabled
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

    @MainActor
    var supportsRotationInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.rotation).isEmpty
    }
    
    @MainActor
    var supportsShadowInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.shadow).isEmpty
    }
    
    @MainActor
    var supportsLayerEffectInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.effects).isEmpty
    }
}
