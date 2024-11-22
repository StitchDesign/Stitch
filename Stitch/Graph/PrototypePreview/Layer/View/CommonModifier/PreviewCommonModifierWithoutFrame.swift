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
    
    // TODO: can you just use the layerViewModel.readSize ?
    var sizeForAnchoringAndGestures: CGSize {
        size.asCGSize(parentSize)
    }
    
    // Assumes parentSize has already been scaled etc.
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var stroke: LayerStrokeData {
        // shape layers will already have had their strokes applied
        isForShapeLayer ? .defaultEmptyStroke : layerViewModel.getLayerStrokeData()
    }
    
    var pos: StitchPosition {
        adjustPosition(
            size: layerViewModel.readSize,
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
                stroke: stroke))
        
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
                nodeId: interactiveLayer.id.layerNodeId,
                highlightedSidebarLayers: document.graphUI.highlightedSidebarLayers,
                scale: scale))
        
            .modifier(PreviewLayerRotationModifier(
                document: document,
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ))
        
            .scaleEffect(CGFloat(scale),
                         anchor: pivot.toPivot)
                
            .modifier(PreviewCommonPositionModifier(
                document: document,
                viewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                parentDisablesPosition: parentDisablesPosition, 
                parentSize: parentSize,
                pos: pos))
                
        //  SwiftUI gestures must come AFTER the .position modifier
            .modifier(PreviewWindowElementSwiftUIGestures(
                document: document,
                interactiveLayer: interactiveLayer,
                position: position,
                pos: pos,
                size: sizeForAnchoringAndGestures,
                parentSize: parentSize,
                minimumDragDistance: minimumDragDistance))
    }
}

