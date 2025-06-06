//
//  PreviewAbsoluteShapeLayerModifier.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 6/13/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// TODO: should a shape that uses absolute-coordinate-space be able to use `grow` and group orientation?
// TODO: revisit this modifier; main purpose is just to use .offset instead of .position when a Shape is using Absolute Coordinate Space ?
struct PreviewAbsoluteShapeLayerModifier: ViewModifier {

    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    @Bindable var viewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let position: CGPoint // offset
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let scale: Double
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let pivot: Anchoring

    // aka size
    let previewWindowSize: CGSize

    var size: CGSize {
        previewWindowSize
    }

    var parentSize: CGSize {
        previewWindowSize
    }

    func body(content: Content) -> some View {

        content
            .frame(width: size.width,
                   height: size.height,
                   alignment: .center)
            
        //            .modifier(PreviewCommonSizeModifier(
        //                size: size,
        //                parentSize: parentSize,
        //                textLayerAlignment: .center))

            .modifier(PreviewLayerRotationModifier(
                graph: graph,
                viewModel: viewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                rotationX: rotationX,
                rotationY: rotationY,
                rotationZ: rotationZ))

            .scaleEffect(scale,
                         anchor: pivot.toPivot)

            // For Absolute Layer shapes, position is more like "offset" than an actual position
            .offset(x: position.x, y: position.y)
        
        //            .modifier(PreviewCommonPositionModifier(
        //                size: size,
        //                position: position,
        //                anchoring: anchoring,
        //                parentSize: parentSize,
        //                parentDisablesPosition: parentDisablesPosition))

            .modifier(PreviewLayerEffectsModifier(
                blurRadius: blurRadius,
                blendMode: blendMode,
                brightness: brightness,
                colorInvert: colorInvert,
                contrast: contrast,
                hueRotation: hueRotation,
                saturation: saturation))
        
            // SwiftUI gestures must come AFTER the .position modifier
            .modifier(PreviewWindowElementSwiftUIGestures(
                document: document,
                graph: graph,
                interactiveLayer: interactiveLayer,
                pos: position,
                // TODO: For handling Press interaction location with Custom Shape layer that uses absolute-coordinate space, what needs to change?
                size: size.toLayerSize,
                parentSize: parentSize,
                minimumDragDistance: DEFAULT_MINIMUM_DRAG_DISTANCE))
    }
}
