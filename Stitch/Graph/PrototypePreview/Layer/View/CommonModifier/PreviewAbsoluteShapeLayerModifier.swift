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

    @Bindable var graph: GraphState
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
                graph: graph,
                interactiveLayer: interactiveLayer,
                position: position,
                // TODO: For handling Press interaction location with Custom Shape layer that uses absolute-coordinate space, what needs to change?
                // Normally we subtract the anchoring-adjusted position (i.e. `pos`), but that assumes using a .position, not .offset, modifier
                pos: position.toCGSize, // TOOD: anchoring and size
                size: size,
                parentSize: parentSize,
                minimumDragDistance: DEFAULT_MINIMUM_DRAG_DISTANCE))
    }
}
