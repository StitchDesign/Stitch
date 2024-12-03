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
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .enabled,
        .size,
        .position,
        .anchoring,
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
        PreviewRadialGradientLayer(
            document: document,
            graph: graph,
            layerViewModel: viewModel,
            isPinnedViewRendering: isPinnedViewRendering,
            interactiveLayer: viewModel.interactiveLayer,
            enabled: viewModel.enabled.getBool ?? true,
            position: viewModel.position.getPosition ?? .zero,
            size: viewModel.size.getSize ?? .zero,
            opacity: viewModel.opacity.getNumber ?? defaultOpacityNumber,
            scale: viewModel.scale.getNumber ?? 1,
            anchoring: viewModel.anchoring.getAnchoring ?? .defaultAnchoring,
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
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid)
    }
}


struct PreviewRadialGradientLayer: View {
    let document: StitchDocumentViewModel
    @Bindable var graph: GraphState
    let layerViewModel: LayerViewModel
    let isPinnedViewRendering: Bool
    let interactiveLayer: InteractiveLayer
    let enabled: Bool
    let position: CGPoint
    let size: LayerSize
    let opacity: Double
    let scale: Double
    let anchoring: Anchoring
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
    let parentIsScrollableGrid: Bool

    var body: some View {

        RadialGradient(colors: [firstColor, secondColor],
                       center: startPoint.toUnitPointType,
                       startRadius: startRadius,
                       endRadius: endRadius)
        .opacity(enabled ? opacity : 0.0)
        .modifier(PreviewCommonModifier(
            document: document,
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
            anchoring: anchoring,
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
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid))
    }
}
