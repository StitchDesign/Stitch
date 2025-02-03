//
//  LinearGradientNode.swift
//  Stitch
//
//  Created by Nicholas Arner on 4/19/24.
//

import Foundation
import SwiftUI
import StitchSchemaKit
@preconcurrency import OrderedCollections

public typealias LayerInputPortSet = OrderedSet<LayerInputPort>
let DEFAULT_GRADIENT_START_COLOR = Color(.yellow)
let DEFAULT_GRADIENT_END_COLOR = Color(.blue)

struct LinearGradientLayerNode: LayerNodeDefinition {
    
    static let layer = Layer.linearGradient
    
    static let inputDefinitions: LayerInputPortSet = .init([
        .enabled,
        .position,
        .size,
        .opacity,
        .scale,
        .anchoring,
        .zIndex,
        .startAnchor,
        .endAnchor,
        .startColor,
        .endColor
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
                        realityContent: LayerRealityCameraContent?) -> some View {
        PreviewLinearGradientLayer(
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
            startPoint: viewModel.startAnchor.getAnchoring ?? .defaultGradientStartAnchoring,
            endPoint: viewModel.endAnchor.getAnchoring ?? .defaultGradientEndAnchoring,
            firstColor: viewModel.startColor.getColor ?? .yellow,
            secondColor: viewModel.endColor.getColor ?? .blue,
            parentSize: parentSize,
            parentDisablesPosition: parentDisablesPosition,
            parentIsScrollableGrid: parentIsScrollableGrid)
    }
}


struct PreviewLinearGradientLayer: View {
    @Bindable var document: StitchDocumentViewModel
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
    let endPoint: Anchoring
    let firstColor: Color
    let secondColor: Color
    let parentSize: CGSize
    let parentDisablesPosition: Bool
    let parentIsScrollableGrid: Bool

    var body: some View {

        LinearGradient(colors: [firstColor, secondColor],
                       startPoint: startPoint.toUnitPointType,
                       endPoint: endPoint.toUnitPointType)
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




extension Anchoring {
    static let defaultGradientStartAnchoring: Anchoring = .topCenter
    static let defaultGradientEndAnchoring: Anchoring = .bottomCenter

    var toUnitPointType: UnitPoint {
        switch self {
        case .topLeft:
            return .topLeading
        case .topCenter:
            return .top
        case .topRight:
            return .topTrailing
        case .centerLeft:
            return .leading
        case .centerCenter:
            return .center
        case .centerRight:
            return .trailing
        case .bottomLeft:
            return .bottomLeading
        case .bottomCenter:
            return .bottom
        case .bottomRight:
            return .bottomTrailing
        default:
            return .center
        }
    }
}

 let defaultGradientStartAnchoring: Anchoring = .topCenter
 let defaultGradientEndAnchoring: Anchoring = .bottomCenter
