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

struct PropertySidebarState: Equatable {
    var selectedProperty: LayerInspectorRowId?
    
    // Used for positioning flyouts; read and populated by every row,
    // even if row does not support a flyout or has no active flyout.
    // TODO: use `x` of left edge of property sidebar
    var propertyRowOrigins: [LayerInputType: CGPoint] = .init()
    
    // Only layer inputs (not fields or outputs) can have flyouts
    var flyoutState: PropertySidebarFlyoutState? = nil
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

//enum FlyoutKind: Equatable {
//    case padding(width: 300.0, )
//}

extension LayerInspectorView {
    // TODO: fill these out
        
    // TODO: better?: make the LayerInputTypeSet enum CaseIterable and have the enum ordering as the source of truth for this order
    @MainActor
    static let allInputs: LayerInputTypeSet = Self.required
        .union(Self.positioning)
        .union(Self.sizing)
        .union(Self.common)
        .union(Self.groupLayer)
        .union(Self.unknown)
        .union(Self.text)
        .union(Self.stroke)
        .union(Self.rotation)
        .union(Self.shadow)
        .union(Self.effects)
    
    
    @MainActor
    static let required: LayerInputTypeSet = [
        .scale,
        .opacity,
        .pivot, // pivot point for scaling; put with
    ]
    
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
        .masks,
        .clipped,
        
        .color, // Text color vs Rectangle color
        
        // Hit Area
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
    
    // TODO: what are these inputs?
    @MainActor
    static let unknown: LayerInputTypeSet = [
        .lineColor,
        .lineWidth,
        .enabled // what is this?
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
    
 
    @MainActor
    var supportsGroupInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.groupLayer).isEmpty
    }
    
    @MainActor
    var supportsUnknownInputs: Bool {
        let layerInputs = self.layerGraphNode.inputDefinitions
        return !layerInputs.intersection(LayerInspectorView.unknown).isEmpty
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
