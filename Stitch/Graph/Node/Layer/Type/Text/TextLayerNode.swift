//
//  TextNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 3/23/21.
//

import Foundation
import StitchSchemaKit
import SwiftUI

let DEFAULT_TEXT_VALUE = String("Text")

extension CGSize {
    static let LAYER_DEFAULT_SIZE: Self = .init(width: 100, height: 100)
}

extension LayerSize {
    static let LAYER_DEFAULT_SIZE: Self = .init(width: 100, height: 100)
}

extension LayerSize {
    static let DEFAULT_TEXT_LABEL_SIZE: Self = .init(width: 100, height: 100)
}

extension Color {
    static let LAYER_DEFAULT_COLOR: Color = STITCH_PURPLE
}

func initialLayerColor() -> Color {
    #if DEV_DEBUG
    return .randomAssortedColor
    #else
    return .LAYER_DEFAULT_COLOR
    #endif
}

// A single line of text seems to be 25 high
let defaultTextSize = CGSize(width: 200, height: 75).toLayerSize

struct TextLayerNode: LayerNodeDefinition {
    static let layer = Layer.text

    static let inputDefinitions: LayerInputPortSet = .init([
        .text,
        .color,
        .position,
        .rotationX,
        .rotationY,
        .rotationZ,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .pivot,
        .masks,
        .shadowColor,
        .shadowOpacity,
        .shadowRadius,
        .shadowOffset
    ])
    .union(.layerEffects)
    .union(.strokeInputs)
    .union(.typography)
    .union(.aspectRatio)
    .union(.sizing)
    .union(.pinning)
    .union(.layerPaddingAndMargin)
    .union(.offsetInGroup)
    
    
    
    static func content(document: StitchDocumentViewModel,
                        graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool,
                        parentIsScrollableGrid: Bool,
                        realityContent: Binding<LayerRealityCameraContent?>) -> some View {
        PreviewTextLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            text: viewModel.text.display,
            color: viewModel.color.getColor ?? falseColor,
            position: viewModel.position.getPosition ?? .zero,
            rotationX: viewModel.rotationX.asCGFloat,
            rotationY: viewModel.rotationY.asCGFloat,
            rotationZ: viewModel.rotationZ.asCGFloat,
            size: viewModel.size.getSize ?? .zero,
            opacity: viewModel.opacity.getNumber ?? .zero,
            scale: viewModel.scale.getNumber ?? .zero,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
            fontSize: viewModel.fontSize.getLayerDimension ?? .DEFAULT_FONT_SIZE,
            textAlignment: viewModel.textAlignment.getLayerTextAlignment ?? DEFAULT_TEXT_ALIGNMENT,
            verticalAlignment: viewModel.verticalAlignment.getLayerTextVerticalAlignment ?? DEFAULT_TEXT_VERTICAL_ALIGNMENT,
            textDecoration: viewModel.textDecoration.getTextDecoration ?? .defaultLayerTextDecoration,
            textFont: viewModel.textFont.getTextFont ?? .defaultStitchFont,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            pivot: viewModel.pivot.getAnchoring ?? .defaultPivot,
            shadowColor: viewModel.shadowColor.getColor ?? .defaultShadowColor,
            shadowOpacity: viewModel.shadowOpacity.getNumber ?? .defaultShadowOpacity,
            shadowRadius: viewModel.shadowRadius.getNumber ?? .defaultShadowOpacity,
            shadowOffset: viewModel.shadowOffset.getPosition ?? .defaultShadowOffset,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid)
    }
}
