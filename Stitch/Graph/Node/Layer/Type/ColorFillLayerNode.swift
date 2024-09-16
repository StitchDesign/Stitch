//
//  ColorFillLayerNode.swift
//  Stitch
//
//  Created by Christian J Clampitt on 12/12/22.
//

import Foundation
import SwiftUI
import StitchSchemaKit

// ColorFill layer node does not have an size input; rather its size is always 100% of its (immediately above) parent.
let colorFillLayerSize = LayerSize(width: .parentPercent(100),
                                   height: .parentPercent(100))

struct ColorFillLayerNode: LayerNodeDefinition {

    static let layer = Layer.colorFill
    
    static let inputDefinitions: LayerInputTypeSet = .init([
        .enabled,
        .color,
        .opacity,
        .zIndex
    ])
        .union(.layerEffects)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)
    
    static func content(document: StitchDocumentViewModel,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool) -> some View {
        PreviewColorFillLayer(
            document: document,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            enabled: viewModel.enabled.getBool ?? true,
            color: viewModel.color.getColor ?? .falseColor,
            opacity: viewModel.opacity.getNumber ?? defaultOpacityNumber,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            parentSize: parentSize,
            parentDisablesPosition: true)
    }
}
