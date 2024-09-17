//
//  PreviewColorFillLayer.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/12/22.
//

import SwiftUI
import StitchSchemaKit

struct PreviewColorFillLayer: View {
    @Bindable var document: StitchDocumentViewModel
    let layerViewModel: LayerViewModel
    let position: CGPoint = .zero

    var size: LayerSize {
        parentSize.toLayerSize
    }

    // struct PreviewColorFillLayer: View {
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let enabled: Bool
    let color: Color
    let opacity: Double
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var body: some View {

        // ColorFill layer is always same size as its parent
        return color.opacity(enabled ? opacity : 0.0)
            //            .frame(parentSize)
            .modifier(PreviewCommonModifier(
                document: document,
                layerViewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                interactiveLayer: interactiveLayer,
                position: position,
                rotationX: .zero,
                rotationY: .zero,
                rotationZ: .zero,
                size: .init(parentSize),
                scale: 1,
                anchoring: .topLeft,
                blurRadius: blurRadius,
                blendMode: blendMode,
                brightness: brightness,
                colorInvert: colorInvert,
                contrast: contrast,
                hueRotation: hueRotation,
                saturation: saturation, 
                pivot: .defaultPivot,
                shadowColor: .defaultShadowColor,
                shadowOpacity: .defaultShadowOpacity,
                shadowRadius: .defaultShadowRadius,
                shadowOffset: .defaultShadowOffset,
                parentSize: parentSize,
                parentDisablesPosition: parentDisablesPosition))
    }
}

// struct PreviewColorFillLayer_Previews: PreviewProvider {
//    static var previews: some View {
//        PreviewColorFillLayer()
//    }
// }
