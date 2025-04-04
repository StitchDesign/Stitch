//
//  PreviewCommonModifierWithoutFrame.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// Note: used by many but not all layers; e.g. Group Layer does not use this
struct PreviewCommonModifierWithoutFrame: ViewModifier {

    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    
    let position: StitchPosition
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    
    // let this default to .zero, since only the Toggle Switch (and Progress Indicator?) need non-zero min-drag-distances
    var minimumDragDistance: Double = .zero
    
    let scale: Double
    let anchoring: Anchoring
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let pivot: Anchoring
    
    let shadowColor: Color
    let shadowOpacity: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: StitchPosition
    
    var isForShapeLayer: Bool = false
    
    // Assumes parentSize has already been scaled etc.
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool

    var stroke: LayerStrokeData {
        // shape layers will already have had their strokes applied
        isForShapeLayer ? .defaultEmptyStroke : layerViewModel.getLayerStrokeData()
    }
    
    var pos: StitchPosition {
        adjustPosition(
//            size: layerViewModel.readSize, // Already includes size-changes from scaling
//            size: size.asCGSize(parentSize),

            // SEE NOTE IN `asCGSizeForLayer`
            size: size.asCGSizeForLayer(parentSize: parentSize,
                                        readSize: layerViewModel.readSize),
            position: position,
            anchor: anchoring,
            parentSize: parentSize)
    }
    
    func body(content: Content) -> some View {

        return content
        
        // Margin input comes *after* `.frame`
        // Should be applied before layer-effects, rotation etc.?
            .modifier(LayerPaddingModifier(padding: layerViewModel.layerMargin.getPadding ?? .defaultPadding))
        
        // TODO: How do layer-padding and layer-margin inputs affect stroke ?
            .modifier(ApplyStroke(
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                stroke: stroke,
                cornerRadius: layerViewModel.cornerRadius.getNumber ?? .zero))
        
            .modifier(PreviewLayerEffectsModifier(
                blurRadius: blurRadius,
                blendMode: blendMode,
                brightness: brightness,
                colorInvert: colorInvert,
                contrast: contrast,
                hueRotation: hueRotation,
                saturation: saturation))
        
        // Doesn't matter whether SwiftUI .shadow modifier comes before or after .scaleEffect, .position, etc. ?
            .modifier(PreviewShadowModifier(
                shadowColor: shadowColor,
                shadowOpacity: shadowOpacity,
                shadowRadius: shadowRadius,
                shadowOffset: shadowOffset))
        
        // should be BEFORE .scale, .position, .offset and .rotation, so that border can be affected by those changes; but AFTER layer-effects, so that e.g. masking or blur does
            .modifier(PreviewSidebarHighlightModifier(
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                nodeId: interactiveLayer.id.layerNodeId.asNodeId,
                highlightedSidebarLayers: graph.layersSidebarViewModel.highlightedSidebarLayers,
                scale: scale))
        
            .modifier(PreviewLayerRotationModifier(
                graph: graph,
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ))
        
            .scaleEffect(CGFloat(scale),
                         anchor: pivot.toPivot)
                
            .modifier(PreviewCommonPositionModifier(
                graph: graph,
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                parentDisablesPosition: parentDisablesPosition,
                parentIsScrollableGrid: parentIsScrollableGrid,
                parentSize: parentSize,
                pos: pos))
                
        //  SwiftUI gestures must come AFTER the .position modifier
            .modifier(PreviewWindowElementSwiftUIGestures(
                document: document,
                graph: graph,
                interactiveLayer: interactiveLayer,
                position: position,
                size: size,
                readSize: layerViewModel.readSize,
                anchoring: anchoring,
                parentSize: parentSize,
                minimumDragDistance: minimumDragDistance))
    }
}

