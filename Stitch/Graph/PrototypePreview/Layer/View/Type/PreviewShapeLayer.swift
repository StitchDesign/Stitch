//
//  PreviewShape.swift
//  prototype
//
//  Created by Christian J Clampitt on 4/29/21.
//

import SwiftUI
import StitchSchemaKit

// `InsettableShape` protocol means we can use .strokeBorder modifier;
// available for SwiftUI Shapes like Ellipse and RoundedRectangle,
// but not currently implemented for CGPoints/Path-based custom shapes like our Triangle;
/// `struct PreviewShapeLayer<T: View & InsettableShape>: View, CommonView {`
///
struct PreviewShapeLayer: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    
    let color: Color
    let position: StitchPosition
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    let stroke: LayerStrokeData
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

    let previewShapeKind: PreviewShapeLayerKind
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    
    let usesAbsoluteCoordinates: Bool
    
    var layerNodeSize: CGSize {
        size.asCGSize(parentSize)
    }
    
    // Used by outside-strokes on non-custom shapes
    var pos: StitchPosition {
        adjustPosition(
            // TODO: use `layerViewModel.readSize` instead?
            size: layerNodeSize.scaleBy(scale),
            position: position,
            anchor: anchoring,
            parentSize: parentSize)
    }
    
    var body: some View {
        
        let shape = builtShape(layerNodeSize: layerNodeSize)
        
        // After we've applied Shape- and InsettableShape-based SwiftUI modifiers,
        // we apply the common modifiers:
        if usesAbsoluteCoordinates {
            shape
                .opacity(opacity)
                .modifier(PreviewSidebarHighlightModifier(
                    viewModel: layerViewModel,
                    isPinnedViewRendering: isPinnedViewRendering,
                    nodeId: interactiveLayer.id.layerNodeId,
                    highlightedSidebarLayers: document.graphUI.highlightedSidebarLayers,
                    scale: scale))
            // order of .blur vs other modiifers doesn't matter?
                .blur(radius: blurRadius)
                .blendMode(blendMode.toBlendMode)
            
            // TODO: revisit this
                .modifier(PreviewAbsoluteShapeLayerModifier(
                    document: document,
                    graph: graph,
                    viewModel: layerViewModel,
                    isPinnedViewRendering: isPinnedViewRendering,
                    interactiveLayer: interactiveLayer,
                    position: position,
                    rotationX: rotationX,
                    rotationY: rotationY,
                    rotationZ: rotationZ,
                    scale: scale,
                    blurRadius: blurRadius,
                    blendMode: blendMode,
                    brightness: brightness,
                    colorInvert: colorInvert,
                    contrast: contrast,
                    hueRotation: hueRotation,
                    saturation: saturation,
                    pivot: pivot,
                    previewWindowSize: parentSize))
        } else {
            shape
                .opacity(opacity)
                .modifier(PreviewCommonModifier(
                    document: document,
                    graph: graph,
                    layerViewModel: layerViewModel,
                    isPinnedViewRendering: isPinnedViewRendering,
                    interactiveLayer: interactiveLayer,
                    position: position,
                    rotationX: rotationX,
                    rotationY: rotationY,
                    rotationZ: rotationZ,
                    size: size,
                    scale: scale,
                    anchoring: anchoring,
                    blurRadius: blurRadius,
                    blendMode: blendMode,
                    brightness: brightness,
                    colorInvert: colorInvert,
                    contrast: contrast,
                    hueRotation: hueRotation,
                    saturation: saturation,
                    pivot: pivot,
                    shadowColor: shadowColor,
                    shadowOpacity: shadowOpacity,
                    shadowRadius: shadowRadius,
                    shadowOffset: shadowOffset,
                    isForShapeLayer: true,
                    parentSize: parentSize,
                    parentDisablesPosition: parentDisablesPosition))
        }
    }
    
    @ViewBuilder
    func builtShape(layerNodeSize: CGSize) -> some View {
        StitchShape(
            stroke: stroke,
            color: color,
            opacity: opacity,
            layerNodeSize: layerNodeSize,
            previewShapeKind: previewShapeKind,
            usesAbsoluteCoordinates: usesAbsoluteCoordinates)
    }
}
