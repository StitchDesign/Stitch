//  AngularGradientNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 4/19/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
import OrderedCollections

let DEFAULT_ANGULAR_GRADIENT_START_ANGLE = Double(1)
let DEFAULT_ANGULAR_GRADIENT_END_ANGLE = Double(100)

struct AngularGradientLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.angularGradient
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .enabled,
        .size,
        .position,
        .anchoring,
        .startColor,
        .endColor,
        .centerAnchor,
        .startAngle,
        .endAngle,
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
                        parentDisablesPosition: Bool) -> some View {
        PreviewAngularGradientLayer(
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
            firstColor: viewModel.startColor.getColor ?? .yellow,
            secondColor: viewModel.endColor.getColor ?? .blue,
            centerAnchor: viewModel.centerAnchor.getAnchoring ?? .topCenter,
            startAngle: viewModel.startAngle.getNumber ?? DEFAULT_ANGULAR_GRADIENT_START_ANGLE,
            endAngle: viewModel.endAngle.getNumber ?? DEFAULT_ANGULAR_GRADIENT_END_ANGLE,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition)
    }
}


struct PreviewAngularGradientLayer: View {
    let document: StitchDocumentViewModel
    let graph: GraphState
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
    let firstColor: Color
    let secondColor: Color
    let centerAnchor: Anchoring
    let startAngle: Double
    let endAngle: Double
    let parentSize: CGSize
    let parentDisablesPosition: Bool

    var body: some View {

        //TODO: SET CENTER
        return AngularGradient(colors: [firstColor, secondColor],
                               center: centerAnchor.toUnitPointType,
                               startAngle: Angle(degrees: startAngle),
                               endAngle: Angle(degrees: endAngle))
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
                parentDisablesPosition: parentDisablesPosition))
    }
}
