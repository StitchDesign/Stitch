//  RadialGradientLayerNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 4/19/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import OrderedCollections

let DEFAULT_RADIAL_GRADIENT_START_RADIUS = Double(0)
let DEFAULT_RADIAL_GRADIENT_END_RADIUS = Double(200)

struct RadialGradientLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.radialGradient
    
    static let inputDefinitions: LayerInputTypeSet = .init([
        .enabled,
        .startColor,
        .endColor,
        .startAnchor,
        .startRadius,
        .endRadius,
        .opacity,
        .scale,
        .zIndex
    ])
        .union(.layerEffects)
        .union(.aspectRatio)
        .union(.sizing).union(.pinning).union(.layerPaddingAndMargin).union(.offsetInGroup)
    
    static func content(graph: GraphState,
                        viewModel: LayerViewModel,
                        parentSize: CGSize,
                        layersInGroup: LayerDataList, 
                        isPinnedViewRendering: Bool,
                        parentDisablesPosition: Bool) -> some View {
        PreviewRadialGradientLayer(
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            enabled: viewModel.enabled.getBool ?? true,
            opacity: viewModel.opacity.getNumber ?? defaultOpacityNumber,
            scale: viewModel.scale.getNumber ?? 1,
            blurRadius: viewModel.blurRadius.getNumber ?? .zero,
            blendMode: viewModel.blendMode.getBlendMode ?? .defaultBlendMode,
            brightness: viewModel.brightness.getNumber ?? .defaultBrightnessForLayerEffect,
            colorInvert: viewModel.colorInvert.getBool ?? .defaultColorInvertForLayerEffect,
            contrast: viewModel.contrast.getNumber ?? .defaultContrastForLayerEffect,
            hueRotation: viewModel.hueRotation.getNumber ?? .defaultHueRotationForLayerEffect,
            saturation: viewModel.saturation.getNumber ?? .defaultSaturationForLayerEffect,
            startPoint: viewModel.startAnchor.getAnchoring ?? .topCenter,
            firstColor: viewModel.startColor.getColor ?? .yellow,
            secondColor: viewModel.endColor.getColor ?? .blue,
            startRadius: viewModel.startRadius.getNumber ?? DEFAULT_RADIAL_GRADIENT_START_RADIUS,
            endRadius: viewModel.endRadius.getNumber ?? DEFAULT_RADIAL_GRADIENT_END_RADIUS,
            parentSize: parentSize,
            parentDisablesPosition: true)
    }
}


struct PreviewRadialGradientLayer: View {
    var graph: GraphState
    let layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let enabled: Bool
    let opacity: Double
    let scale: Double
    let blurRadius: CGFloat
    let blendMode: StitchBlendMode
    let brightness: Double
    let colorInvert: Bool
    let contrast: Double
    let hueRotation: Double
    let saturation: Double
    let startPoint: Anchoring
    let firstColor: Color
    let secondColor: Color
    let startRadius: Double
    let endRadius: Double
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let position: CGSize = .zero

    var size: LayerSize {
        parentSize.toLayerSize
    }

    var body: some View {

        return RadialGradient(colors: [firstColor, secondColor],
                              center: startPoint.toUnitPointType,
                              startRadius: startRadius,
                              endRadius: endRadius)
            .opacity(enabled ? opacity : 0.0)
            .modifier(PreviewCommonModifier(
                graph: graph,
                layerViewModel: layerViewModel,
                isPinnedViewRendering: isPinnedViewRendering,
                interactiveLayer: interactiveLayer,
                position: position,
                rotationX: .zero,
                rotationY: .zero,
                rotationZ: .zero,
                size: size,
                scale: scale,
                anchoring: .defaultAnchoring,
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
