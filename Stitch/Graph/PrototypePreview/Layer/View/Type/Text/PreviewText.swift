//
//  Text.swift
//  Stitch
//
//  Created by Christian J Clampitt on 2/26/21.
//

import Foundation
import SwiftUI
import StitchSchemaKit

let DEFAULT_TEXT_ALIGNMENT: LayerTextAlignment = .left

let DEFAULT_TEXT_VERTICAL_ALIGNMENT: LayerTextVerticalAlignment = .top

let defaultTextAlignment = PortValue.textAlignment(DEFAULT_TEXT_ALIGNMENT)

let defaultTextVerticalAlignment = PortValue.textVerticalAlignment(DEFAULT_TEXT_VERTICAL_ALIGNMENT)

struct PreviewTextLayer: View {
    @Bindable var document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let text: String
    let color: Color
    let position: CGPoint
    let rotationX: CGFloat
    let rotationY: CGFloat
    let rotationZ: CGFloat
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
    
    let fontSize: LayerDimension
    let textAlignment: LayerTextAlignment
    let verticalAlignment: LayerTextVerticalAlignment
    let textDecoration: LayerTextDecoration
    let textFont: StitchFont
    
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
    
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var body: some View {

        let alignment: Alignment? = getSwiftUIAlignment(textAlignment, verticalAlignment)
        
        LayerTextView(value: text,
                      color: color,
                      alignment: alignment,
                      fontSize: fontSize,
                      textDecoration: textDecoration,
                      textFont: textFont)
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
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            frameAlignment: alignment ?? .topLeading
        ))
    }
}

//struct PreviewText_Preview: PreviewProvider {
//
//    static var previews: some View {
//
//        let id = LayerNodeId.randomLayerNodeId
//
//        return PreviewTextLayer(
//            graph: graph,
//            interactiveLayer: .init(id: PreviewCoordinate(layerNodeId: id, loopIndex: 0)),
//            text: "Some sample text here...",
//            color: .blue,
//            position: CGSize(width: 30,
//                             height: 40),
//            rotationX: 0,
//            rotationY: 0,
//            rotationZ: 0,
//            size: LayerSize(width: 300, height: 400),
//            opacity: defaultOpacityNumber,
//            scale: defaultScaleNumber,
//            anchoring: .bottomCenter,
//            fontSize: DEFAULT_LAYER_TEXT_FONT_SIZE,
//            textAlignment: DEFAULT_TEXT_ALIGNMENT,
//            verticalAlignment: DEFAULT_TEXT_VERTICAL_ALIGNMENT,
//            textDecoration: .defaultLayerTextDecoration,
//            textFont: .defaultStitchFont,
//            blurRadius: .zero,
//            blendMode: .defaultBlendMode,
//            brightness: .zero,
//            colorInvert: false,
//            contrast: .zero,
//            hueRotation: .zero,
//            saturation: .zero,
//            parentSize: CGSize(width: 600,
//                               height: 800))
//    }
//}
